const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "us-central1", maxInstances: 5 });

const GEMINI_MODEL = "gemini-2.5-flash";
const LOCATION = "us-central1";

function genAiClient() {
  // Uses Vertex AI on the function's own Google Cloud project/credentials —
  // no separate API key needed, but the Vertex AI API must be enabled on the project.
  return new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT,
    location: LOCATION,
  });
}

/** Pulls the first {...} or [...] block out of a model response and parses it. */
function extractJson(text) {
  const match = text.match(/[[{][\s\S]*[\]}]/);
  if (!match) throw new Error(`No JSON found in model response: ${text.slice(0, 200)}`);
  return JSON.parse(match[0]);
}

/** Summarizes the company's project/application history for prompt context. */
async function buildCompanyProfile() {
  const [projectsSnap, applicationsSnap] = await Promise.all([
    db.collection("projects").limit(100).get(),
    db.collection("applications").limit(100).get(),
  ]);

  const projects = projectsSnap.docs.map((d) => {
    const p = d.data();
    return `- ${p.name} (${p.status}) for ${p.client || "internal"}: ${p.description || ""} [${(p.techStack || []).join(", ")}]`;
  });

  const applications = applicationsSnap.docs.map((d) => {
    const a = d.data();
    return `- ${a.name}: ${a.description || ""} [${(a.techStack || []).join(", ")}] areas: ${(a.applicationAreas || []).join(", ")}`;
  });

  return [
    "Company past/current/planned projects:",
    projects.length ? projects.join("\n") : "(none recorded yet)",
    "",
    "Company-built applications:",
    applications.length ? applications.join("\n") : "(none recorded yet)",
  ].join("\n");
}

/**
 * Callable: discoverApplicationAreas
 * Input: { name, description }
 * Runs a Google Search-grounded Gemini call to suggest real-world application
 * areas / industries for a given company application.
 */
exports.discoverApplicationAreas = onCall(async (request) => {
  const { name, description } = request.data || {};
  if (!name) throw new HttpsError("invalid-argument", "name is required");

  const ai = genAiClient();
  const prompt = `You are a market research assistant. Using web search, find real-world
application areas / industries / use cases for a software system called "${name}".
Description: ${description || "(none provided)"}

Return ONLY a JSON object of the form {"areas": ["area 1", "area 2", ...]}
with 5-10 concise application areas (2-6 words each). No commentary, no markdown fences.`;

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
    config: { tools: [{ googleSearch: {} }] },
  });

  const text = response.text ?? "";
  let parsed;
  try {
    parsed = extractJson(text);
  } catch (e) {
    logger.error("discoverApplicationAreas: failed to parse model output", e, text);
    throw new HttpsError("internal", "Model did not return parseable JSON");
  }

  return { areas: Array.isArray(parsed.areas) ? parsed.areas : [] };
});

/**
 * Core discovery routine shared by the callable and the scheduled trigger.
 * Searches the web for open contracts/tenders relevant to the company profile,
 * scores each against that profile, and writes new (deduped by sourceUrl)
 * contracts into Firestore. Returns the number of newly created documents.
 */
async function runContractDiscovery(query) {
  const profile = await buildCompanyProfile();
  const ai = genAiClient();

  const prompt = `You are a business development assistant for a software company with this profile:

${profile}

Using web search, find up to 8 currently open contracts, tenders, RFPs, or client
opportunities${query ? ` related to: ${query}` : " that this company is realistically qualified to bid on"}.
For each one, estimate a fit score (0-100) for how well this company's stack and
experience match the opportunity, and briefly justify the score.

Return ONLY a JSON array, each item shaped as:
{
  "title": string,
  "description": string,
  "sourceUrl": string,
  "client": string | null,
  "deadline": string | null (ISO 8601 date, or null if unknown),
  "tags": string[],
  "fitScorePercent": number (0-100),
  "fitReasoning": string
}
No commentary, no markdown fences.`;

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
    config: { tools: [{ googleSearch: {} }] },
  });

  const text = response.text ?? "";
  let candidates;
  try {
    candidates = extractJson(text);
  } catch (e) {
    logger.error("runContractDiscovery: failed to parse model output", e, text);
    throw new HttpsError("internal", "Model did not return parseable JSON");
  }
  if (!Array.isArray(candidates)) candidates = [];

  let created = 0;
  for (const c of candidates) {
    if (!c.sourceUrl || !c.title) continue;

    const existing = await db
      .collection("contracts")
      .where("sourceUrl", "==", c.sourceUrl)
      .limit(1)
      .get();
    if (!existing.empty) continue;

    const now = admin.firestore.Timestamp.now();
    await db.collection("contracts").add({
      title: c.title,
      description: c.description || "",
      sourceUrl: c.sourceUrl,
      client: c.client || null,
      deadline: c.deadline ? admin.firestore.Timestamp.fromDate(new Date(c.deadline)) : null,
      status: "discovered",
      fitScorePercent: Math.max(0, Math.min(100, Math.round(c.fitScorePercent || 0))),
      fitReasoning: c.fitReasoning || "",
      tags: Array.isArray(c.tags) ? c.tags : [],
      discoveredAt: now,
      updatedAt: now,
    });
    created += 1;
  }

  logger.info(`runContractDiscovery: created ${created} of ${candidates.length} candidates`);
  return created;
}

/** Callable: searchContracts — { query?: string } -> { created: number } */
exports.searchContracts = onCall(async (request) => {
  const created = await runContractDiscovery(request.data?.query);
  return { created };
});

/** Scheduled: runs the same discovery routine automatically every Monday. */
exports.scheduledContractDiscovery = onSchedule("every monday 08:00", async () => {
  await runContractDiscovery();
});
