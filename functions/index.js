const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");
const {
  isGroundingRedirectStub,
  checkUrlReachable,
} = require("./connectors/tenderSourceConnector");
const {
  isRelevantCandidate,
  isAllowedCountry,
  classifyGeographyPriority,
  GEOGRAPHY_PRIORITY_RANK,
} = require("./opportunityRelevance");
const { applyGroundedUrlCrossCheck } = require("./lib/groundedUrlValidation");

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

  const profile = await buildCompanyProfile();
  const ai = genAiClient();
  const prompt = `You are a market research assistant for a software company with this track record:

${profile}

Using web search, find real-world application areas / industries / use cases
for a new software system called "${name}".
Description: ${description || "(none provided)"}

For each area, briefly explain why it fits (1-2 sentences), grounded in web
search findings and, where relevant, the company's existing experience above.

Return ONLY a JSON object of the form
{"areas": [{"area": "area name", "reasoning": "why it fits"}, ...]}
with 5-8 entries (area names 2-6 words each). No commentary, no markdown fences.`;

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

  const rawAreas = Array.isArray(parsed.areas) ? parsed.areas : [];
  const areas = rawAreas
    .filter((a) => a && a.area)
    .map((a) => ({ area: String(a.area), reasoning: String(a.reasoning || "") }));

  return { areas };
});

/**
 * Core discovery routine shared by the callable and the scheduled trigger.
 * Searches the web for open opportunities/tenders relevant to the company profile,
 * scores each against that profile, and writes new (deduped by sourceUrl)
 * opportunities into Firestore. Returns the number of newly created documents.
 */
async function runOpportunityDiscovery(query) {
  const profile = await buildCompanyProfile();
  const ai = genAiClient();

  const prompt = `You are a business development assistant for a software company with this profile:

${profile}

Using web search, find up to 8 currently open opportunities, tenders, RFPs, or client
opportunities${query ? ` related to: ${query}` : " that this company is realistically qualified to bid on"}.
For each one, estimate a fit score (0-100) for how well this company's stack and
experience match the opportunity, and briefly justify the score.

GEOGRAPHY — only include opportunities located in Kenya, Uganda, Tanzania,
Rwanda, or Burundi. Do not include opportunities from any other country
(e.g. Canada, the UK, the US, or elsewhere in Africa) even if they otherwise
look like a strong match — they will be discarded regardless of fit score,
so do not waste a slot on one.

CRITICAL — "sourceUrl" must be a direct, real, publicly loadable link to the
actual tender/opportunity page as it appears in the address bar of the site
that published it — the exact URL a person could paste into a browser and
land on that tender. Copy this URL EXACTLY as it appears in your search
results/grounding data — character for character. NEVER type out, guess,
reconstruct, or paraphrase a URL from a page's title even if you are
confident you know its slug or numbering scheme; if you did not literally
see the URL in your search results, you do not have it. NEVER return a
Google Search redirect/citation link (any URL on a
"vertexaisearch.cloud.google.com" or similar Google-hosted redirect domain)
— those are internal citation artifacts, not something a person can open
later, and are worthless here. If you cannot determine the real, direct URL
for an opportunity, omit that opportunity entirely rather than guessing or
substituting a search-result link.

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
If none of the opportunities you found have a real, verifiable sourceUrl,
return an empty JSON array: []
Return ONLY the JSON array — no commentary, no markdown fences, no
explanation before or after it, even when the array is empty.`;

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
    // The stricter "never guess a URL, omit the opportunity instead"
    // instruction above means the model legitimately has nothing to report
    // more often than before — it sometimes explains that in prose ("no
    // verifiable opportunities found...") instead of returning `[]`, which
    // extractJson treats as a parse failure. Since an empty result is an
    // expected, non-error outcome here, log it for visibility and continue
    // with zero candidates rather than failing the whole run (same handling
    // ApiConnector._syncAiSearch already uses for the identical case).
    logger.warn(
      "runOpportunityDiscovery: model returned no parseable JSON — treating as zero candidates",
      e,
      text,
    );
    candidates = [];
  }
  if (!Array.isArray(candidates)) candidates = [];

  // Exact-URL grounding cross-check — drops any candidate whose sourceUrl
  // isn't backed by a page Google Search grounding actually retrieved (fails
  // closed when grounding metadata is present but unresolvable, never falls
  // back to a domain-only match). Same shared logic apiConnector.js's
  // TenderSource-based AI search already uses — see
  // lib/groundedUrlValidation.js for why this must run before the
  // relevance/geography pre-filter below, not after: a fabricated URL must
  // never survive regardless of how relevant its title looks.
  const candidatesFromModel = candidates.length;
  const { kept: groundedCandidates } = await applyGroundedUrlCrossCheck(
    candidates,
    response,
    { logPrefix: "runOpportunityDiscovery" },
  );
  candidates = groundedCandidates;
  const groundingDroppedCount = candidatesFromModel - candidates.length;

  // Deterministic pre-filter (expired/malformed/non-tender content) before
  // any candidate is written — see isRelevantCandidate. HARD geography gate:
  // isAllowedCountry drops anything outside Kenya/Uganda/Tanzania/Rwanda/
  // Burundi regardless of fit score — a 90%+ fit score from Botswana,
  // Toronto, North Carolina, etc. must still be discarded. Survivors are
  // then sorted Kenya -> the other four East African countries so
  // higher-priority opportunities are created (and thus surfaced) first
  // within this run; see classifyGeographyPriority.
  const beforeGeographyCount = candidates.filter((c) => isRelevantCandidate(c)).length;
  const relevantCandidates = candidates
    .filter((c) => isRelevantCandidate(c) && isAllowedCountry(c))
    .map((c) => ({ candidate: c, geographyPriority: classifyGeographyPriority(c) }))
    .sort(
      (a, b) =>
        GEOGRAPHY_PRIORITY_RANK[a.geographyPriority] -
        GEOGRAPHY_PRIORITY_RANK[b.geographyPriority],
    );
  const relevanceDroppedCount = candidates.length - beforeGeographyCount;
  const geographyDroppedCount = beforeGeographyCount - relevantCandidates.length;

  let created = 0;
  let verifiedCount = 0;
  let unverifiedCount = 0;
  for (const { candidate: c, geographyPriority } of relevantCandidates) {
    // Same fabrication risk as ApiConnector._syncAiSearch (this uses the
    // identical Gemini + Google Search grounding technique) — drop any
    // candidate whose sourceUrl is a Google grounding-redirect citation
    // stub rather than a real page. See tenderSourceConnector.js.
    if (isGroundingRedirectStub(c.sourceUrl)) continue;

    const existing = await db
      .collection("opportunities")
      .where("sourceUrl", "==", c.sourceUrl)
      .limit(1)
      .get();
    if (!existing.empty) continue;

    const now = admin.firestore.Timestamp.now();
    const { reachable: sourceUrlVerified, finalUrl } = await checkUrlReachable(c.sourceUrl);
    const sourceUrl = sourceUrlVerified && finalUrl ? finalUrl : c.sourceUrl;
    if (sourceUrlVerified) {
      verifiedCount += 1;
    } else {
      unverifiedCount += 1;
    }
    await db.collection("opportunities").add({
      title: c.title,
      description: c.description || "",
      sourceUrl,
      sourceUrlVerified,
      sourceUrlVerifiedAt: sourceUrlVerified ? now : null,
      sourceUrlIsFallback: false,
      client: c.client || null,
      deadline: c.deadline ? admin.firestore.Timestamp.fromDate(new Date(c.deadline)) : null,
      status: "discovered",
      fitScorePercent: Math.max(0, Math.min(100, Math.round(c.fitScorePercent || 0))),
      fitReasoning: c.fitReasoning || "",
      tags: Array.isArray(c.tags) ? c.tags : [],
      geographyPriority,
      discoveredAt: now,
      updatedAt: now,
    });
    created += 1;
  }

  // One summary line per run showing where candidates were lost at each
  // stage — grounding cross-check, relevance/geography pre-filter, and
  // reachability verification — so a run that "found nothing" or "found
  // mostly unverified links" is diagnosable from Cloud Logging alone,
  // without having to correlate several separate log lines.
  logger.info(
    `runOpportunityDiscovery: ${candidatesFromModel} from model -> ` +
      `${groundingDroppedCount} dropped (grounding), ` +
      `${relevanceDroppedCount} dropped (relevance), ` +
      `${geographyDroppedCount} dropped (geography — outside Kenya/Uganda/Tanzania/Rwanda/Burundi), ` +
      `${created} created (${verifiedCount} verified, ${unverifiedCount} unverified)`,
  );
  return created;
}

/**
 * Callable: searchOpportunities — { query?: string } -> { created: number }
 * 240s (default is 60s): runOpportunityDiscovery now does a real HTTP
 * reachability check per surviving candidate before writing it — see
 * checkUrlReachable in tenderSourceConnector.js.
 */
exports.searchOpportunities = onCall({ timeoutSeconds: 240 }, async (request) => {
  const created = await runOpportunityDiscovery(request.data?.query);
  return { created };
});

/** Scheduled: runs the same discovery routine automatically every Monday. */
exports.scheduledOpportunityDiscovery = onSchedule(
  { schedule: "every monday 08:00", timeoutSeconds: 240 },
  async () => {
    await runOpportunityDiscovery();
  },
);

// ====================================================================
// Milestone 3.3 — AI Opportunity Classification
// ====================================================================

/** Firestore collections that make up the Company Knowledge Graph. */
const KNOWLEDGE_GRAPH_COLLECTIONS = [
  { collection: "businessUnits", field: "businessUnitIds", label: "Business Units", textFields: ["name", "summary"] },
  { collection: "products", field: "productIds", label: "Products", textFields: ["name", "summary"] },
  { collection: "services", field: "serviceIds", label: "Services", textFields: ["name", "summary"] },
  { collection: "capabilities", field: "capabilityIds", label: "Capabilities", textFields: ["name", "summary"] },
  { collection: "technologies", field: "technologyIds", label: "Technologies", textFields: ["name", "category"] },
  { collection: "industries", field: "industryIds", label: "Industries", textFields: ["name", "sector"] },
  { collection: "experiences", field: "experienceIds", label: "Past Experiences", textFields: ["title", "summary"] },
  { collection: "knowledgeBase", field: "knowledgeArticleIds", label: "Knowledge Base Articles", textFields: ["title", "category", "summary"] },
];

const CLASSIFICATION_ENUM_FIELDS = {
  estimatedComplexity: ["low", "medium", "high"],
  riskLevel: ["low", "medium", "high"],
  priority: ["low", "medium", "high"],
  classificationStatus: ["classified", "needsReview"],
};

/**
 * Fetches every Company Knowledge Graph collection once, and returns both a
 * prompt-ready text summary (each item prefixed with its Firestore doc ID,
 * so the model can reference specific items back) and the set of valid IDs
 * per field — the latter is what the validation layer checks AI-returned
 * IDs against, so a hallucinated ID can never reach Firestore.
 */
async function buildKnowledgeGraph() {
  const snapshots = await Promise.all(
    KNOWLEDGE_GRAPH_COLLECTIONS.map((c) => db.collection(c.collection).limit(200).get()),
  );

  const sections = [];
  const validIds = {};

  KNOWLEDGE_GRAPH_COLLECTIONS.forEach((c, i) => {
    const snap = snapshots[i];
    const lines = snap.docs.map((d) => {
      const data = d.data();
      const text = c.textFields.map((f) => data[f]).filter(Boolean).join(" - ");
      return `- [${d.id}] ${text}`;
    });
    sections.push(`${c.label}:\n${lines.length ? lines.join("\n") : "(none recorded yet)"}`);
    validIds[c.field] = new Set(snap.docs.map((d) => d.id));
  });

  return { text: sections.join("\n\n"), validIds };
}

/** Builds the classification prompt given the opportunity + knowledge graph context. */
function buildClassificationPrompt({ title, description, knowledgeGraphText }) {
  return `You are a bid/opportunity classification assistant for a company whose
full internal knowledge graph is listed below. Every entry is prefixed with
its unique ID in square brackets — when referencing an entry, you MUST use
that exact ID and no other. Never invent an ID that isn't listed.

${knowledgeGraphText}

Classify the following opportunity against the knowledge graph above:

Title: ${title}
Description: ${description || "(no description provided)"}

Return ONLY a JSON object of the form:
{
  "classificationSummary": string (2-4 sentences explaining the fit),
  "industryIds": string[] (IDs from the Industries list above, or []),
  "technologyIds": string[] (IDs from the Technologies list above, or []),
  "businessUnitIds": string[] (IDs from the Business Units list above, or []),
  "productIds": string[] (IDs from the Products list above, or []),
  "serviceIds": string[] (IDs from the Services list above, or []),
  "capabilityIds": string[] (IDs from the Capabilities list above, or []),
  "experienceIds": string[] (IDs from the Past Experiences list above, or []),
  "knowledgeArticleIds": string[] (IDs from the Knowledge Base Articles list above, or []),
  "estimatedComplexity": "low" | "medium" | "high",
  "priority": "low" | "medium" | "high",
  "riskLevel": "low" | "medium" | "high",
  "confidenceScore": number (0-100, your confidence in this classification),
  "classificationStatus": "classified" | "needsReview" (use "needsReview" if
    the description is too vague or thin to classify with reasonable confidence)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validation layer: never trusts the model's output directly. Every ID
 * field is filtered down to only IDs that actually exist in [validIds] —
 * this is what stops a hallucinated ID from ever reaching Firestore, and
 * what allows a *partial* classification (some fields good, some
 * missing/invalid) to still be accepted rather than discarding the whole
 * response. Every enum field falls back to `null` (or, for
 * classificationStatus, to "needsReview") if the model returned something
 * outside the allowed set.
 */
function validateClassification(parsed, validIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Classification response was not a JSON object");
  }

  const result = {
    classificationSummary: typeof parsed.classificationSummary === "string"
      ? parsed.classificationSummary
      : "",
  };

  for (const { field } of KNOWLEDGE_GRAPH_COLLECTIONS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    const valid = validIds[field] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  for (const [field, allowed] of Object.entries(CLASSIFICATION_ENUM_FIELDS)) {
    result[field] = allowed.includes(parsed[field]) ? parsed[field] : null;
  }
  if (!result.classificationStatus) result.classificationStatus = "needsReview";

  const score = Number(parsed.confidenceScore);
  result.confidenceScore = Number.isFinite(score)
    ? Math.max(0, Math.min(100, Math.round(score)))
    : null;

  return result;
}

/** Calls Gemini with [prompt] and returns the raw parsed JSON (unvalidated). Throws on any failure. */
async function callGeminiForJson(prompt) {
  const ai = genAiClient();
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
  });

  const text = response.text ?? "";
  if (!text.trim()) throw new Error("Empty response from model");

  return extractJson(text);
}

/**
 * Retries an async [attempt] up to [maxAttempts] times, covering transient
 * API failures, timeouts surfaced as thrown errors, and invalid/unparseable
 * JSON alike — any of those simply counts as a failed attempt and is
 * retried the same way. Throws the last error if every attempt fails.
 * Shared by classifyOpportunity and analyzeOpportunityMatch (Milestone 3.4).
 */
async function retryAsync(attempt, { label, maxAttempts = 3 }) {
  let lastError;
  for (let i = 1; i <= maxAttempts; i++) {
    try {
      return await attempt();
    } catch (e) {
      lastError = e;
      logger.warn(`${label}: attempt ${i}/${maxAttempts} failed`, e);
    }
  }
  throw lastError;
}

/**
 * Callable: classifyOpportunity — { opportunityId: string }
 * Runs Gemini against the opportunity + full Company Knowledge Graph (no
 * web search grounding needed here — everything it reasons over is already
 * in Firestore) and writes the classification fields directly onto the
 * opportunity document. Sets `classificationStatus: "processing"` before
 * the call so the live-streamed UI can show that immediately, then
 * "classified" or "needsReview" once it resolves.
 */
exports.classifyOpportunity = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    const { opportunityId } = request.data || {};
    if (!opportunityId) throw new HttpsError("invalid-argument", "opportunityId is required");

    const oppRef = db.collection("opportunities").doc(opportunityId);
    const oppSnap = await oppRef.get();
    if (!oppSnap.exists) throw new HttpsError("not-found", "Opportunity not found");
    const opportunity = oppSnap.data();

    await oppRef.update({
      classificationStatus: "processing",
      updatedAt: admin.firestore.Timestamp.now(),
    });

    const { text: knowledgeGraphText, validIds } = await buildKnowledgeGraph();
    const prompt = buildClassificationPrompt({
      title: opportunity.title,
      description: opportunity.description,
      knowledgeGraphText,
    });

    let result;
    try {
      result = await retryAsync(
        async () => validateClassification(await callGeminiForJson(prompt), validIds),
        { label: "classifyOpportunity" },
      );
    } catch (e) {
      logger.error("classifyOpportunity: all attempts failed", e);
      await oppRef.update({
        classificationStatus: "needsReview",
        aiReviewedAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
      throw new HttpsError("internal", "AI classification failed after retries");
    }

    const now = admin.firestore.Timestamp.now();
    // businessUnitIds is deliberately NOT overwritten unconditionally like
    // the other knowledge-graph relationship fields below — it now also
    // drives the Opportunities screen's BU tabs/filters (Phase 2), so a
    // human who has already set it (via the Opportunity Workspace's
    // Business Units picker, or a prior classification run) must never
    // have that choice silently reverted by a later reclassification.
    // Only fill it in when it's currently empty.
    const existingBusinessUnitIds = Array.isArray(opportunity.businessUnitIds)
      ? opportunity.businessUnitIds
      : [];
    const businessUnitIdsToWrite =
      existingBusinessUnitIds.length > 0
        ? existingBusinessUnitIds
        : result.businessUnitIds;

    await oppRef.update({
      classificationSummary: result.classificationSummary,
      industryIds: result.industryIds,
      technologyIds: result.technologyIds,
      businessUnitIds: businessUnitIdsToWrite,
      productIds: result.productIds,
      serviceIds: result.serviceIds,
      capabilityIds: result.capabilityIds,
      experienceIds: result.experienceIds,
      knowledgeArticleIds: result.knowledgeArticleIds,
      estimatedComplexity: result.estimatedComplexity,
      priority: result.priority,
      riskLevel: result.riskLevel,
      confidenceScore: result.confidenceScore,
      classificationStatus: result.classificationStatus,
      aiReviewedAt: now,
      updatedAt: now,
    });

    return {
      ...result,
      businessUnitIds: businessUnitIdsToWrite,
      aiReviewedAt: now.toDate().toISOString(),
    };
  },
);

// ====================================================================
// Milestone 3.4 — AI Opportunity Match Analysis
// ====================================================================
//
// Classification (3.3) answers "what is this opportunity"; this answers
// "how well does JV ALMA CIS match it" — a distinct AI pass, over the same
// Company Knowledge Graph, writing to a disjoint set of Opportunity fields.
// Reuses buildKnowledgeGraph/callGeminiForJson/retryAsync from 3.3 rather
// than re-fetching the graph or re-implementing retry a second time.

const MATCH_SCORE_FIELDS = [
  "overallMatchScore",
  "businessUnitScore",
  "productScore",
  "serviceScore",
  "capabilityScore",
  "technologyScore",
  "industryScore",
  "experienceScore",
  "knowledgeScore",
];

/** Recommended-ID fields on the match analysis result, and which buildKnowledgeGraph() validIds set each is checked against. */
const MATCH_RECOMMENDATION_FIELDS = [
  { field: "recommendedProductIds", validKey: "productIds" },
  { field: "recommendedBusinessUnitIds", validKey: "businessUnitIds" },
  { field: "recommendedExperienceIds", validKey: "experienceIds" },
  { field: "recommendedKnowledgeArticleIds", validKey: "knowledgeArticleIds" },
];

/** Free-form narrative bullet-point fields — validated as string arrays only, no ID checking. */
const MATCH_TEXT_LIST_FIELDS = ["strengths", "gaps", "risks", "nextActions"];

function clampScore(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, Math.round(n)));
}

/** Builds the match-analysis prompt given the opportunity + knowledge graph context. */
function buildMatchAnalysisPrompt({ title, description, knowledgeGraphText }) {
  return `You are a strategic fit-analysis assistant for JV ALMA CIS. You
already know the company's internal knowledge graph, listed below with
each entry's unique ID in square brackets — when recommending an entry you
MUST use that exact ID and no other. Never invent an ID that isn't listed.

${knowledgeGraphText}

The following opportunity has already been classified elsewhere — do not
re-classify it. Instead, analyze how well JV ALMA CIS specifically matches
it, using the knowledge graph above as evidence:

Title: ${title}
Description: ${description || "(no description provided)"}

Score fit from 0-100 in each category below (0 = no relevant match at all,
100 = ideal match), give an overall score, recommend the specific existing
knowledge-graph entries most relevant as supporting evidence, and assess
the opportunity strategically.

Return ONLY a JSON object of the form:
{
  "overallMatchScore": number (0-100),
  "businessUnitScore": number (0-100),
  "productScore": number (0-100),
  "serviceScore": number (0-100),
  "capabilityScore": number (0-100),
  "technologyScore": number (0-100),
  "industryScore": number (0-100),
  "experienceScore": number (0-100),
  "knowledgeScore": number (0-100),
  "strategicRecommendation": string (2-4 sentences),
  "recommendedProductIds": string[] (IDs from the Products list above, or []),
  "recommendedBusinessUnitIds": string[] (IDs from the Business Units list above, or []),
  "recommendedExperienceIds": string[] (IDs from the Past Experiences list above, or []),
  "recommendedKnowledgeArticleIds": string[] (IDs from the Knowledge Base Articles list above, or []),
  "strengths": string[] (short bullet phrases, no IDs),
  "gaps": string[] (short bullet phrases, no IDs),
  "risks": string[] (short bullet phrases, no IDs),
  "nextActions": string[] (short, concrete recommended next steps)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validation layer for match analysis — the same philosophy as
 * validateClassification: every recommended ID is filtered down to IDs
 * that actually exist in [validIds] (never a hallucinated reference),
 * every score is clamped into 0-100 or left `null`, and a partial result
 * (some fields good, some missing) is accepted rather than the whole
 * response being discarded.
 */
function validateMatchAnalysis(parsed, validIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Match analysis response was not a JSON object");
  }

  const result = {};

  for (const field of MATCH_SCORE_FIELDS) {
    result[field] = clampScore(parsed[field]);
  }

  result.strategicRecommendation = typeof parsed.strategicRecommendation === "string"
    ? parsed.strategicRecommendation
    : "";

  for (const { field, validKey } of MATCH_RECOMMENDATION_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    const valid = validIds[validKey] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  for (const field of MATCH_TEXT_LIST_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    result[field] = raw
      .filter((s) => typeof s === "string" && s.trim().length > 0)
      .map((s) => s.trim());
  }

  return result;
}

/**
 * Callable: analyzeOpportunityMatch — { opportunityId: string }
 * Runs Gemini against the opportunity + full Company Knowledge Graph (same
 * graph fetch as classifyOpportunity, no web search grounding needed) and
 * writes the match-analysis fields directly onto the opportunity document.
 * Unlike classification, there is no intermediate "processing" status
 * field for match analysis — the client shows its own loading state instead.
 */
exports.analyzeOpportunityMatch = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    const { opportunityId } = request.data || {};
    if (!opportunityId) throw new HttpsError("invalid-argument", "opportunityId is required");

    const oppRef = db.collection("opportunities").doc(opportunityId);
    const oppSnap = await oppRef.get();
    if (!oppSnap.exists) throw new HttpsError("not-found", "Opportunity not found");
    const opportunity = oppSnap.data();

    const { text: knowledgeGraphText, validIds } = await buildKnowledgeGraph();
    const prompt = buildMatchAnalysisPrompt({
      title: opportunity.title,
      description: opportunity.description,
      knowledgeGraphText,
    });

    let result;
    try {
      result = await retryAsync(
        async () => validateMatchAnalysis(await callGeminiForJson(prompt), validIds),
        { label: "analyzeOpportunityMatch" },
      );
    } catch (e) {
      logger.error("analyzeOpportunityMatch: all attempts failed", e);
      throw new HttpsError("internal", "AI match analysis failed after retries");
    }

    const now = admin.firestore.Timestamp.now();
    await oppRef.update({
      ...result,
      matchAnalyzedAt: now,
      updatedAt: now,
    });

    return {
      ...result,
      matchAnalyzedAt: now.toDate().toISOString(),
    };
  },
);

// ====================================================================
// Milestone 3.5 — AI Strategic Review
// ====================================================================
//
// Classification (3.3) answers "what is this opportunity"; match analysis
// (3.4) answers "how well do we match it"; this answers the executive
// question "should we pursue it, and how" — a third AI pass over the same
// Company Knowledge Graph, but also fed the opportunity's own
// classification/match-analysis fields (already on the document) as extra
// context, rather than re-deriving them from title/description alone.
// Reuses buildKnowledgeGraph/callGeminiForJson/retryAsync unchanged.

const STRATEGIC_REVIEW_RECOMMENDATION_VALUES = ["pursue", "pursueWithCaution", "doNotPursue"];

/** Recommended-ID fields on the strategic review result, and which buildKnowledgeGraph() validIds set each is checked against. */
const STRATEGIC_REVIEW_RECOMMENDATION_FIELDS = [
  { field: "strategicReviewBusinessUnitIds", validKey: "businessUnitIds" },
  { field: "strategicReviewProductIds", validKey: "productIds" },
  { field: "strategicReviewServiceIds", validKey: "serviceIds" },
  { field: "strategicReviewCapabilityIds", validKey: "capabilityIds" },
  { field: "strategicReviewTechnologyIds", validKey: "technologyIds" },
  { field: "strategicReviewExperienceIds", validKey: "experienceIds" },
  { field: "strategicReviewKnowledgeArticleIds", validKey: "knowledgeArticleIds" },
];

/** Free-form narrative bullet-point fields — validated as string arrays only, no ID checking. */
const STRATEGIC_REVIEW_TEXT_LIST_FIELDS = [
  "strategicStrengths",
  "strategicWeaknesses",
  "strategicRisks",
  "mitigationStrategies",
  "competitiveAdvantages",
  "missingRequirements",
  "nextRecommendedActions",
];

/** Builds the strategic-review prompt given the opportunity + its prior AI outputs + knowledge graph context. */
function buildStrategicReviewPrompt({
  title,
  description,
  knowledgeGraphText,
  classificationSummary,
  matchAnalysisSummary,
}) {
  return `You are an executive strategic-review assistant for JV ALMA CIS
management, deciding whether the company should pursue a business
opportunity. You already know the company's internal knowledge graph,
listed below with each entry's unique ID in square brackets — when
recommending an entry you MUST use that exact ID and no other. Never invent
an ID that isn't listed.

${knowledgeGraphText}

The opportunity below has already been classified and match-analyzed
elsewhere in the system — use those existing findings as input to your
strategic reasoning rather than re-deriving them from scratch:

Title: ${title}
Description: ${description || "(no description provided)"}
Existing classification summary: ${classificationSummary || "(not yet classified)"}
Existing match analysis: ${matchAnalysisSummary || "(not yet analyzed)"}

Reason over the knowledge graph above (business units, products, services,
capabilities, technologies, industries, experiences, knowledge base) to
produce an executive decision-support review. Do not perform keyword
matching — explain the business case.

Return ONLY a JSON object of the form:
{
  "executiveRecommendation": "pursue" | "pursueWithCaution" | "doNotPursue",
  "executiveSummary": string (2-4 sentences summarizing the business case),
  "strategicStrengths": string[] (short bullet phrases),
  "strategicWeaknesses": string[] (short bullet phrases),
  "strategicRisks": string[] (short bullet phrases),
  "mitigationStrategies": string[] (short bullet phrases, one per major risk where possible),
  "competitiveAdvantages": string[] (short bullet phrases to emphasize in a proposal),
  "missingRequirements": string[] (capabilities/evidence the company is missing or should shore up before submission),
  "strategicReviewBusinessUnitIds": string[] (IDs from the Business Units list above — which should lead this pursuit),
  "strategicReviewProductIds": string[] (IDs from the Products list above to highlight),
  "strategicReviewServiceIds": string[] (IDs from the Services list above to highlight),
  "strategicReviewCapabilityIds": string[] (IDs from the Capabilities list above to highlight),
  "strategicReviewTechnologyIds": string[] (IDs from the Technologies list above to highlight),
  "strategicReviewExperienceIds": string[] (IDs from the Past Experiences list above as supporting evidence),
  "strategicReviewKnowledgeArticleIds": string[] (IDs from the Knowledge Base Articles list above as supporting evidence),
  "proposalPositioningStrategy": string (2-4 sentences on how to position the proposal),
  "nextRecommendedActions": string[] (short, concrete recommended next steps before submission)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validation layer for strategic review — the same philosophy as
 * validateMatchAnalysis: every recommended ID is filtered down to IDs that
 * actually exist in [validIds] (never a hallucinated reference), the
 * recommendation enum falls back to `null` if outside the allowed set, and
 * a partial result (some fields good, some missing) is accepted rather than
 * the whole response being discarded.
 */
function validateStrategicReview(parsed, validIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Strategic review response was not a JSON object");
  }

  const result = {
    executiveRecommendation: STRATEGIC_REVIEW_RECOMMENDATION_VALUES.includes(parsed.executiveRecommendation)
      ? parsed.executiveRecommendation
      : null,
    executiveSummary: typeof parsed.executiveSummary === "string" ? parsed.executiveSummary : "",
    proposalPositioningStrategy: typeof parsed.proposalPositioningStrategy === "string"
      ? parsed.proposalPositioningStrategy
      : "",
  };

  for (const { field, validKey } of STRATEGIC_REVIEW_RECOMMENDATION_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    const valid = validIds[validKey] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  for (const field of STRATEGIC_REVIEW_TEXT_LIST_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    result[field] = raw
      .filter((s) => typeof s === "string" && s.trim().length > 0)
      .map((s) => s.trim());
  }

  return result;
}

/**
 * Callable: generateStrategicReview — { opportunityId: string }
 * Runs Gemini against the opportunity (including its existing classification
 * summary and match-analysis recommendation as context) + the full Company
 * Knowledge Graph, and writes the strategic-review fields directly onto the
 * opportunity document. Like match analysis, there is no intermediate
 * "processing" status field — the client shows its own loading state.
 */
exports.generateStrategicReview = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    const { opportunityId } = request.data || {};
    if (!opportunityId) throw new HttpsError("invalid-argument", "opportunityId is required");

    const oppRef = db.collection("opportunities").doc(opportunityId);
    const oppSnap = await oppRef.get();
    if (!oppSnap.exists) throw new HttpsError("not-found", "Opportunity not found");
    const opportunity = oppSnap.data();

    const { text: knowledgeGraphText, validIds } = await buildKnowledgeGraph();
    const prompt = buildStrategicReviewPrompt({
      title: opportunity.title,
      description: opportunity.description,
      knowledgeGraphText,
      classificationSummary: opportunity.classificationSummary,
      matchAnalysisSummary: opportunity.strategicRecommendation,
    });

    let result;
    try {
      result = await retryAsync(
        async () => validateStrategicReview(await callGeminiForJson(prompt), validIds),
        { label: "generateStrategicReview" },
      );
    } catch (e) {
      logger.error("generateStrategicReview: all attempts failed", e);
      throw new HttpsError("internal", "AI strategic review failed after retries");
    }

    const now = admin.firestore.Timestamp.now();
    await oppRef.update({
      ...result,
      strategicReviewedAt: now,
      updatedAt: now,
    });

    return {
      ...result,
      strategicReviewedAt: now.toDate().toISOString(),
    };
  },
);

// ====================================================================
// Milestone 3.6 — AI Recommendations
// ====================================================================
//
// Milestones 3.3-3.5 each run one AI pass scoped to a single opportunity.
// This is different in kind: a portfolio-wide pass over EVERY opportunity
// (using their already-computed classification/match-analysis/strategic-
// review fields as input signal, not re-deriving them) plus the Company
// Knowledge Graph, producing a handful of prioritized, explainable
// recommendations written as new documents in their own `recommendations`
// collection — closer in shape to `runOpportunityDiscovery`/
// `searchOpportunities` (batch document creation) than to
// classifyOpportunity/analyzeOpportunityMatch/generateStrategicReview
// (single-document mutation). Reuses buildKnowledgeGraph/callGeminiForJson/
// retryAsync unchanged.

const RECOMMENDATION_CATEGORY_VALUES = [
  "priorityOpportunity",
  "atRiskOpportunity",
  "capabilityGap",
  "resourceAllocation",
  "general",
];

const RECOMMENDATION_PRIORITY_VALUES = ["low", "medium", "high"];

/** Related-ID fields on a recommendation, and which buildKnowledgeGraph() validIds set each is checked against. */
const RECOMMENDATION_KNOWLEDGE_FIELDS = [
  { field: "relatedBusinessUnitIds", validKey: "businessUnitIds" },
  { field: "relatedProductIds", validKey: "productIds" },
  { field: "relatedServiceIds", validKey: "serviceIds" },
  { field: "relatedCapabilityIds", validKey: "capabilityIds" },
  { field: "relatedTechnologyIds", validKey: "technologyIds" },
  { field: "relatedIndustryIds", validKey: "industryIds" },
  { field: "relatedExperienceIds", validKey: "experienceIds" },
  { field: "relatedKnowledgeArticleIds", validKey: "knowledgeArticleIds" },
];

/**
 * Summarizes every opportunity currently in Firestore, including the AI
 * output already computed on it by earlier milestones (classification
 * summary, overall match score, executive recommendation) — so the
 * recommendations prompt reasons on top of that established intelligence
 * rather than starting from title/description alone. Returns the same
 * `{text, validIds}` shape as `buildKnowledgeGraph()`.
 */
async function buildOpportunityPortfolioSummary() {
  const snap = await db.collection("opportunities").limit(100).get();

  const lines = snap.docs.map((d) => {
    const o = d.data();
    const parts = [
      `[${d.id}] ${o.title}`,
      `status: ${o.status || "discovered"}`,
      `pipelineStage: ${o.pipelineStage || "discovered"}`,
      `fitScore: ${o.fitScorePercent ?? "n/a"}`,
    ];
    if (o.classificationSummary) parts.push(`classification: ${o.classificationSummary}`);
    if (o.overallMatchScore != null) parts.push(`matchScore: ${o.overallMatchScore}`);
    if (o.executiveRecommendation) parts.push(`strategicReview: ${o.executiveRecommendation}`);
    if (o.deadline) parts.push(`deadline: ${o.deadline.toDate().toISOString().slice(0, 10)}`);
    return `- ${parts.join(" | ")}`;
  });

  return {
    text: lines.length ? lines.join("\n") : "(no opportunities recorded yet)",
    validIds: new Set(snap.docs.map((d) => d.id)),
  };
}

/** Builds the recommendations prompt given the opportunity portfolio + knowledge graph context. */
function buildRecommendationsPrompt({ portfolioText, knowledgeGraphText }) {
  return `You are a portfolio-strategy assistant for JV ALMA CIS. You know
the company's internal knowledge graph, listed below with each entry's
unique ID in square brackets, and the current state of every opportunity in
the company's pipeline (each prefixed with its own unique ID) including
whatever classification/match-analysis/strategic-review work has already
been done on it. When referencing an entry or opportunity you MUST use its
exact ID and no other. Never invent an ID that isn't listed.

Company knowledge graph:
${knowledgeGraphText}

Opportunity portfolio:
${portfolioText}

Reason across the whole portfolio and the knowledge graph — do not perform
keyword matching — to produce up to 8 prioritized, actionable business
recommendations for what the company should do next. Examples of the kind of
insight to produce: a specific opportunity worth fast-tracking, a specific
opportunity that looks stalled or at risk, a capability or technology gap
recurring across several opportunities that's worth investing in, or a
business unit that appears over- or under-represented in the current
pipeline. Every recommendation must explain WHY, citing specific evidence.

Return ONLY a JSON array, each item shaped as:
{
  "category": "priorityOpportunity" | "atRiskOpportunity" | "capabilityGap" | "resourceAllocation" | "general",
  "priority": "low" | "medium" | "high",
  "title": string (a short, action-oriented headline, 4-10 words),
  "reasoning": string (2-4 sentences explaining WHY, citing specific evidence),
  "confidenceScore": number (0-100),
  "relatedOpportunityIds": string[] (IDs from the opportunity portfolio above, or []),
  "relatedBusinessUnitIds": string[] (IDs from the Business Units list above, or []),
  "relatedProductIds": string[] (IDs from the Products list above, or []),
  "relatedServiceIds": string[] (IDs from the Services list above, or []),
  "relatedCapabilityIds": string[] (IDs from the Capabilities list above, or []),
  "relatedTechnologyIds": string[] (IDs from the Technologies list above, or []),
  "relatedIndustryIds": string[] (IDs from the Industries list above, or []),
  "relatedExperienceIds": string[] (IDs from the Past Experiences list above, or []),
  "relatedKnowledgeArticleIds": string[] (IDs from the Knowledge Base Articles list above, or [])
}
No commentary, no markdown fences, no explanation outside the JSON array.`;
}

/**
 * Validates a single recommendation candidate. Returns `null` — skipping
 * just this one item rather than failing the whole batch — when it's
 * missing either field with no reasonable default (`title`/`reasoning`).
 * `category`/`priority` fall back to `"general"`/`"medium"` rather than
 * null, since (unlike other AI features' optional enums) these two drive
 * how every recommendation groups/sorts in the UI and can't be left
 * unset. Every ID field is filtered down to IDs that actually exist in
 * [validIds] — never a hallucinated reference.
 */
function validateRecommendationItem(item, validIds) {
  if (!item || typeof item !== "object" || Array.isArray(item)) return null;

  const title = typeof item.title === "string" ? item.title.trim() : "";
  const reasoning = typeof item.reasoning === "string" ? item.reasoning.trim() : "";
  if (!title || !reasoning) return null;

  const result = {
    category: RECOMMENDATION_CATEGORY_VALUES.includes(item.category) ? item.category : "general",
    priority: RECOMMENDATION_PRIORITY_VALUES.includes(item.priority) ? item.priority : "medium",
    title,
    reasoning,
    confidenceScore: clampScore(item.confidenceScore),
    relatedOpportunityIds: Array.isArray(item.relatedOpportunityIds)
      ? item.relatedOpportunityIds.filter((id) => typeof id === "string" && validIds.opportunityIds.has(id))
      : [],
  };

  for (const { field, validKey } of RECOMMENDATION_KNOWLEDGE_FIELDS) {
    const raw = Array.isArray(item[field]) ? item[field] : [];
    const valid = validIds[validKey] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  return result;
}

/**
 * Shared core for both the callable and the scheduled trigger — mirrors
 * `runOpportunityDiscovery`'s split with `searchOpportunities`/
 * `scheduledOpportunityDiscovery`. Skips writing a candidate if an *active*
 * recommendation with the same title already exists, the same
 * exact-field dedup approach `runOpportunityDiscovery` uses for `sourceUrl`,
 * so re-running (manually or on schedule) doesn't spam duplicates. Returns
 * the number of newly created documents.
 */
async function runRecommendationGeneration() {
  const [{ text: knowledgeGraphText, validIds: knowledgeValidIds }, { text: portfolioText, validIds: opportunityIds }] =
    await Promise.all([buildKnowledgeGraph(), buildOpportunityPortfolioSummary()]);
  const validIds = { ...knowledgeValidIds, opportunityIds };

  const prompt = buildRecommendationsPrompt({ portfolioText, knowledgeGraphText });

  let candidates;
  try {
    candidates = await retryAsync(async () => {
      const raw = await callGeminiForJson(prompt);
      if (!Array.isArray(raw)) throw new Error("Recommendations response was not a JSON array");
      return raw;
    }, { label: "generateRecommendations" });
  } catch (e) {
    logger.error("generateRecommendations: all attempts failed", e);
    throw new HttpsError("internal", "AI recommendation generation failed after retries");
  }

  let created = 0;
  for (const candidate of candidates) {
    const result = validateRecommendationItem(candidate, validIds);
    if (!result) continue;

    const existing = await db
      .collection("recommendations")
      .where("status", "==", "active")
      .where("title", "==", result.title)
      .limit(1)
      .get();
    if (!existing.empty) continue;

    const now = admin.firestore.Timestamp.now();
    await db.collection("recommendations").add({
      ...result,
      status: "active",
      generatedAt: now,
      createdAt: now,
      updatedAt: now,
    });
    created += 1;
  }

  logger.info(`runRecommendationGeneration: created ${created} of ${candidates.length} candidates`);
  return created;
}

/** Callable: generateRecommendations -> { created: number } */
exports.generateRecommendations = onCall(
  { timeoutSeconds: 120 },
  async () => {
    const created = await runRecommendationGeneration();
    return { created };
  },
);

/** Scheduled: refreshes recommendations weekly, an hour after the discovery run so new opportunities are already in Firestore. */
exports.scheduledRecommendationRefresh = onSchedule("every monday 09:00", async () => {
  await runRecommendationGeneration();
});

// ====================================================================
// Milestone 3.7 — Opportunity Discovery Engine
// ====================================================================
//
// searchOpportunities/scheduledOpportunityDiscovery (Phase 1, above) remain
// completely untouched: they stay the ad-hoc "quick search, no saved
// source" path. This section adds a parallel, source-based discovery
// architecture: a DiscoverySource is a saved, named configuration (a
// government-procurement feed, a UN-procurement search, etc.); running one
// is bookended by a `discoveryRuns` audit-trail document so every attempt —
// including one against a source type with no automated adapter yet — is
// visible in the Discovery History screen, never silently dropped.
//
// OpportunitySourceAdapter is implemented as a registry (DISCOVERY_ADAPTERS
// below) rather than a class hierarchy, matching this file's existing
// function-based style. The 5 "searchable" source types share ONE adapter
// (runAiWebSearchAdapter) — the difference between them is only which
// phrase targets the Gemini+Google-Search prompt, not a different
// integration. `rss`/`api` are registered with a `null` adapter: an honest
// "not automated yet" marker the dispatcher checks against, per the brief's
// "do not build web scraping for every source yet."

/** Source-type -> prompt-targeting phrase, for the 5 AI-searchable source types. */
const DISCOVERY_SEARCH_ADAPTERS = {
  governmentProcurement: "government procurement portals and public tenders",
  developmentOrganization:
    "development organization funding/procurement opportunities (e.g. World Bank, USAID, bilateral donors)",
  unProcurement: "United Nations agency procurement notices (UNGM, UNDP, UNICEF, etc.)",
  ngo: "NGO and non-profit sector opportunities and partnerships",
  privateSector: "private sector tenders and RFPs",
};

/**
 * Generalized version of `runOpportunityDiscovery`'s body, parameterized by
 * a [source]'s type/name/searchQuery instead of a single free-text query.
 * Same Gemini+googleSearch technique, same sourceUrl-based dedup — every
 * created opportunity additionally records which source produced it
 * (`discoverySourceId`/`discoverySourceType`). Returns
 * `{candidatesFound, created, duplicatesSkipped}` for the calling
 * `runDiscoverySource` to write onto the `discoveryRuns` document.
 */
async function runAiWebSearchAdapter(source) {
  const profile = await buildCompanyProfile();
  const ai = genAiClient();
  const targeting = DISCOVERY_SEARCH_ADAPTERS[source.type] || "open business opportunities";

  const prompt = `You are a business development assistant for a software company with this profile:

${profile}

Using web search, find up to 8 currently open opportunities from ${targeting}${
    source.searchQuery ? `, specifically related to: ${source.searchQuery}` : ""
  }, that this company (source: "${source.name}") is realistically qualified to bid on.
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
    logger.error("runAiWebSearchAdapter: failed to parse model output", e, text);
    throw new Error("Model did not return parseable JSON");
  }
  if (!Array.isArray(candidates)) candidates = [];

  let created = 0;
  let duplicatesSkipped = 0;
  for (const c of candidates) {
    if (!c.sourceUrl || !c.title) continue;

    const existing = await db
      .collection("opportunities")
      .where("sourceUrl", "==", c.sourceUrl)
      .limit(1)
      .get();
    if (!existing.empty) {
      duplicatesSkipped += 1;
      continue;
    }

    const now = admin.firestore.Timestamp.now();
    await db.collection("opportunities").add({
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
      discoverySourceId: source.id,
      discoverySourceType: source.type,
    });
    created += 1;
  }

  return { candidatesFound: candidates.length, created, duplicatesSkipped };
}

/**
 * The `OpportunitySourceAdapter` abstraction: maps each [DiscoverySourceType]
 * to the function that executes a run for it, or `null` if no automated
 * adapter has been built yet. `manual` has no adapter at all — it's a
 * direct-write path (see the Discovery Sources screen's "Add opportunity
 * manually" action), never something `runDiscoverySource` executes.
 */
const DISCOVERY_ADAPTERS = {
  governmentProcurement: runAiWebSearchAdapter,
  developmentOrganization: runAiWebSearchAdapter,
  unProcurement: runAiWebSearchAdapter,
  ngo: runAiWebSearchAdapter,
  privateSector: runAiWebSearchAdapter,
  rss: null,
  api: null,
  manual: null,
};

/**
 * Callable: runDiscoverySource — { sourceId: string, trigger?: "manual" | "scheduled" }
 * -> { opportunitiesCreated: number }
 *
 * Loads the DiscoverySource, dispatches to its registered adapter, and
 * bookends the attempt with a `discoveryRuns` document (`running` ->
 * `completed`/`failed`) so every attempt is visible in Discovery History —
 * including one against a source type with no adapter yet, which still
 * gets a `failed` run doc with a clear message before the callable throws.
 */
exports.runDiscoverySource = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { sourceId, trigger } = request.data || {};
  if (!sourceId) throw new HttpsError("invalid-argument", "sourceId is required");

  const sourceRef = db.collection("discoverySources").doc(sourceId);
  const sourceSnap = await sourceRef.get();
  if (!sourceSnap.exists) throw new HttpsError("not-found", "Discovery source not found");
  const source = { id: sourceId, ...sourceSnap.data() };

  const runTrigger = trigger === "scheduled" ? "scheduled" : "manual";
  const runsCollection = db.collection("discoveryRuns");

  if (source.type === "manual") {
    throw new HttpsError(
      "failed-precondition",
      "Manual sources are not run — add opportunities directly instead.",
    );
  }

  const adapter = DISCOVERY_ADAPTERS[source.type];
  const startedAt = admin.firestore.Timestamp.now();

  if (!adapter) {
    await runsCollection.add({
      sourceId,
      sourceName: source.name || "",
      sourceType: source.type,
      status: "failed",
      trigger: runTrigger,
      candidatesFound: 0,
      opportunitiesCreated: 0,
      duplicatesSkipped: 0,
      errorMessage: `Source type "${source.type}" is not yet automated.`,
      startedAt,
      completedAt: admin.firestore.Timestamp.now(),
    });
    throw new HttpsError(
      "unimplemented",
      `Source type "${source.type}" is not yet automated — use manual entry instead.`,
    );
  }

  const runRef = await runsCollection.add({
    sourceId,
    sourceName: source.name || "",
    sourceType: source.type,
    status: "running",
    trigger: runTrigger,
    candidatesFound: 0,
    opportunitiesCreated: 0,
    duplicatesSkipped: 0,
    errorMessage: null,
    startedAt,
    completedAt: null,
  });

  try {
    const result = await adapter(source);
    await runRef.update({
      status: "completed",
      candidatesFound: result.candidatesFound,
      opportunitiesCreated: result.created,
      duplicatesSkipped: result.duplicatesSkipped,
      completedAt: admin.firestore.Timestamp.now(),
    });
    await sourceRef.update({ lastRunAt: admin.firestore.Timestamp.now() });

    return { opportunitiesCreated: result.created };
  } catch (e) {
    logger.error("runDiscoverySource: adapter failed", e);
    await runRef.update({
      status: "failed",
      errorMessage: String(e && e.message ? e.message : e),
      completedAt: admin.firestore.Timestamp.now(),
    });
    throw new HttpsError("internal", "Discovery run failed");
  }
});

// ====================================================================
// Milestone 3.8 — Tender Source Sync + Connection Test
// ====================================================================
const {
  runTenderSourceSync,
  scheduledTenderSourceSync,
  runAllTenderSourcesNow,
} = require("./tenderSourceSync");
exports.runTenderSourceSync = runTenderSourceSync;
exports.scheduledTenderSourceSync = scheduledTenderSourceSync;
exports.runAllTenderSourcesNow = runAllTenderSourcesNow;

const { testTenderSourceConnection } = require("./testTenderSourceConnection");
exports.testTenderSourceConnection = testTenderSourceConnection;

const { onTenderOpportunityOutcome } = require("./tenderSourceAnalytics");
exports.onTenderOpportunityOutcome = onTenderOpportunityOutcome;

const { seedProductionTenderSources } = require("./seedTenderSources");
exports.seedProductionTenderSources = seedProductionTenderSources;

const { backfillTenderSourceWebsites } = require("./backfillTenderSourceWebsites");
exports.backfillTenderSourceWebsites = backfillTenderSourceWebsites;

const { seedCompanyIntelligenceSpine } = require("./seedCompanyIntelligenceSpine");
exports.seedCompanyIntelligenceSpine = seedCompanyIntelligenceSpine;

const { recheckSourceUrlLinks } = require("./recheckSourceUrlLinks");
exports.recheckSourceUrlLinks = recheckSourceUrlLinks;

const { backfillSourceUrlVerification } = require("./backfillSourceUrlVerification");
exports.backfillSourceUrlVerification = backfillSourceUrlVerification;

// ====================================================================
// Business Workflow Governance — Opportunity Business Unit backfill
// ====================================================================
const { seedCompanyBusinessUnits } = require("./seedCompanyBusinessUnits");
exports.seedCompanyBusinessUnits = seedCompanyBusinessUnits;

const { backfillOpportunityBusinessUnits } = require("./backfillOpportunityBusinessUnits");
exports.backfillOpportunityBusinessUnits = backfillOpportunityBusinessUnits;

const { cleanupOffRegionOpportunities } = require("./cleanupOffRegionOpportunities");
exports.cleanupOffRegionOpportunities = cleanupOffRegionOpportunities;

// ====================================================================
// Milestone 4.2 — AI Proposal Generation Engine
// ====================================================================
//
// Writes proposal-section content the same way every other AI pass in this
// app writes anything: one Gemini call, reasoning over buildKnowledgeGraph()
// plus the opportunity's own classification/match-analysis/strategic-review
// fields (already on the document — Milestones 3.3-3.5) plus a summary of
// any portfolio recommendations that name this opportunity (Milestone 3.6).
// Never generates from the opportunity alone. One callable handles all 5
// generation modes (generate/regenerate/improve/expand/shorten) — the
// difference between them is only the prompt's instruction clause, not a
// different integration, matching the Discovery Engine's "share one
// implementation, vary the framing" precedent (Milestone 3.7). "Reset to
// previous version" is deliberately NOT here — it's a plain client-side
// Firestore write (see ProposalSectionService.restorePreviousVersion),
// no AI call.

const PROPOSAL_GENERATION_MODES = ["generate", "regenerate", "improve", "expand", "shorten"];

/** Recommended-source fields on a generation result, and which buildKnowledgeGraph() validIds set each is checked against. */
const PROPOSAL_SOURCE_FIELDS = [
  { field: "sourceBusinessUnitIds", validKey: "businessUnitIds" },
  { field: "sourceProductIds", validKey: "productIds" },
  { field: "sourceServiceIds", validKey: "serviceIds" },
  { field: "sourceCapabilityIds", validKey: "capabilityIds" },
  { field: "sourceTechnologyIds", validKey: "technologyIds" },
  { field: "sourceIndustryIds", validKey: "industryIds" },
  { field: "sourceExperienceIds", validKey: "experienceIds" },
  { field: "sourceKnowledgeArticleIds", validKey: "knowledgeArticleIds" },
];

/**
 * Summarizes any *active* portfolio recommendations (Milestone 3.6) that
 * name this opportunity — the last link in the reasoning chain the brief
 * specifies (Opportunity -> Classification -> Match Analysis -> Strategic
 * Review -> Recommendations -> knowledge graph -> Proposal Section). A
 * single array-contains filter — no composite index needed.
 */
async function buildRecommendationsContextForOpportunity(opportunityId) {
  const snap = await db
    .collection("recommendations")
    .where("relatedOpportunityIds", "array-contains", opportunityId)
    .limit(5)
    .get();

  if (snap.empty) return "(no active portfolio recommendations reference this opportunity)";

  return snap.docs
    .map((d) => {
      const r = d.data();
      return `- [${r.category || "general"}/${r.priority || "medium"}] ${r.title}: ${r.reasoning}`;
    })
    .join("\n");
}

/**
 * Builds the proposal-section generation prompt. The reasoning chain is
 * explicit in the prompt text itself, exactly as the brief specifies:
 * Opportunity -> Classification -> Match Analysis -> Strategic Review ->
 * Recommendations -> the Company Knowledge Graph -> this section. [mode]
 * changes only the instruction clause; [existingContent] is included for
 * improve/expand/shorten so the model revises rather than starts over.
 */
function buildProposalSectionPrompt({
  sectionType,
  sectionTitle,
  mode,
  existingContent,
  opportunity,
  knowledgeGraphText,
  recommendationsText,
}) {
  const modeInstruction = {
    generate: "Write this section from scratch.",
    regenerate: "Write a fresh version of this section from scratch, replacing the existing draft entirely.",
    improve: "Improve the writing quality of the existing draft below — clearer, more persuasive, more professional — while preserving its meaning and structure.",
    expand: "Expand the existing draft below with more concrete, specific detail, grounded in the context below.",
    shorten: "Condense the existing draft below, preserving only the key points, in a more concise form.",
  }[mode] || "Write this section from scratch.";

  const existingContentBlock =
    mode !== "generate" && existingContent
      ? `\nExisting draft to revise:\n"""\n${existingContent}\n"""\n`
      : "";

  return `You are a proposal-writing assistant for JV ALMA CIS, drafting one
section of a business proposal. You reason using the company's full
opportunity intelligence and knowledge graph below — you never write proposal
content from the opportunity's title/description alone.

Opportunity:
Title: ${opportunity.title}
Description: ${opportunity.description || "(no description provided)"}
Classification summary: ${opportunity.classificationSummary || "(not yet classified)"}
Match analysis: ${opportunity.strategicRecommendation || "(not yet analyzed)"}
Strategic review: ${opportunity.executiveSummary || "(not yet reviewed)"}
Strategic recommendation: ${opportunity.executiveRecommendation || "(none yet)"}

Active portfolio recommendations naming this opportunity:
${recommendationsText}

Company knowledge graph (each entry's unique ID is in square brackets — when
citing an entry as a source you MUST use that exact ID and no other; never
invent an ID that isn't listed):
${knowledgeGraphText}

Now write the "${sectionTitle}" section (type: ${sectionType}) of the
proposal. ${modeInstruction}
${existingContentBlock}
Ground every claim in the opportunity intelligence and knowledge graph above
— do not invent company facts. Write in a professional, persuasive proposal
tone, 2-5 paragraphs.

Return ONLY a JSON object of the form:
{
  "content": string (the section's full text),
  "confidenceScore": number (0-100, your confidence this content is well-grounded),
  "sourceBusinessUnitIds": string[] (IDs from the Business Units list above actually drawn on, or []),
  "sourceProductIds": string[] (IDs from the Products list above actually drawn on, or []),
  "sourceServiceIds": string[] (IDs from the Services list above actually drawn on, or []),
  "sourceCapabilityIds": string[] (IDs from the Capabilities list above actually drawn on, or []),
  "sourceTechnologyIds": string[] (IDs from the Technologies list above actually drawn on, or []),
  "sourceIndustryIds": string[] (IDs from the Industries list above actually drawn on, or []),
  "sourceExperienceIds": string[] (IDs from the Past Experiences list above actually drawn on, or []),
  "sourceKnowledgeArticleIds": string[] (IDs from the Knowledge Base Articles list above actually drawn on, or [])
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validation layer for proposal-section generation — same philosophy as
 * validateMatchAnalysis/validateStrategicReview: `content` is required with
 * no reasonable fallback (throws if missing/empty, same as those two
 * treating their one required field), every source ID is filtered down to
 * IDs that actually exist in [validIds] (never a hallucinated reference),
 * and confidence is clamped into 0-100 or left `null`.
 */
function validateProposalSectionGeneration(parsed, validIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Proposal section generation response was not a JSON object");
  }

  const content = typeof parsed.content === "string" ? parsed.content.trim() : "";
  if (!content) throw new Error("Proposal section generation response had no content");

  const result = { content, confidenceScore: clampScore(parsed.confidenceScore) };

  for (const { field, validKey } of PROPOSAL_SOURCE_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    const valid = validIds[validKey] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  return result;
}

/**
 * Callable: generateProposalSection — { sectionId: string, mode: string }
 * Loads the section -> its proposal -> that proposal's opportunity, builds
 * the knowledge graph + recommendations context, generates content via
 * Gemini, and writes it directly onto the `proposalSections` document.
 * Snapshots the section's current content/status into
 * previousContent/previousStatus first if there's non-empty content to
 * protect (a single-slot undo buffer — see ProposalSectionService.
 * restorePreviousVersion) — this is what makes "never overwrite user edits
 * without confirmation" possible on the client (the client decides whether
 * to warn before calling; the server always preserves what was there).
 */
exports.generateProposalSection = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { sectionId, mode } = request.data || {};
  if (!sectionId) throw new HttpsError("invalid-argument", "sectionId is required");
  if (!PROPOSAL_GENERATION_MODES.includes(mode)) {
    throw new HttpsError("invalid-argument", "mode must be one of: " + PROPOSAL_GENERATION_MODES.join(", "));
  }

  const sectionRef = db.collection("proposalSections").doc(sectionId);
  const sectionSnap = await sectionRef.get();
  if (!sectionSnap.exists) throw new HttpsError("not-found", "Proposal section not found");
  const section = sectionSnap.data();

  const proposalSnap = await db.collection("proposals").doc(section.proposalId).get();
  if (!proposalSnap.exists) throw new HttpsError("not-found", "Proposal not found");
  const proposal = proposalSnap.data();

  const opportunitySnap = await db.collection("opportunities").doc(proposal.opportunityId).get();
  if (!opportunitySnap.exists) throw new HttpsError("not-found", "Opportunity not found");
  const opportunity = opportunitySnap.data();

  const [{ text: knowledgeGraphText, validIds }, recommendationsText] = await Promise.all([
    buildKnowledgeGraph(),
    buildRecommendationsContextForOpportunity(proposal.opportunityId),
  ]);

  const prompt = buildProposalSectionPrompt({
    sectionType: section.type,
    sectionTitle: section.title,
    mode,
    existingContent: section.content,
    opportunity,
    knowledgeGraphText,
    recommendationsText,
  });

  let result;
  try {
    result = await retryAsync(
      async () => validateProposalSectionGeneration(await callGeminiForJson(prompt), validIds),
      { label: "generateProposalSection" },
    );
  } catch (e) {
    logger.error("generateProposalSection: all attempts failed", e);
    throw new HttpsError("internal", "AI proposal generation failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  const update = {
    content: result.content,
    status: "aiDrafted",
    aiGeneratedAt: now,
    aiConfidence: result.confidenceScore,
    aiSourceBusinessUnitIds: result.sourceBusinessUnitIds,
    aiSourceProductIds: result.sourceProductIds,
    aiSourceServiceIds: result.sourceServiceIds,
    aiSourceCapabilityIds: result.sourceCapabilityIds,
    aiSourceTechnologyIds: result.sourceTechnologyIds,
    aiSourceIndustryIds: result.sourceIndustryIds,
    aiSourceExperienceIds: result.sourceExperienceIds,
    aiSourceKnowledgeArticleIds: result.sourceKnowledgeArticleIds,
    updatedAt: now,
  };

  // Single-slot undo: only overwrite the buffer if there's real prior
  // content worth protecting.
  if (section.content && section.content.trim()) {
    update.previousContent = section.content;
    update.previousStatus = section.status || "notStarted";
  }

  await sectionRef.update(update);

  return {
    content: result.content,
    confidenceScore: result.confidenceScore,
    sourceBusinessUnitIds: result.sourceBusinessUnitIds,
    sourceProductIds: result.sourceProductIds,
    sourceServiceIds: result.sourceServiceIds,
    sourceCapabilityIds: result.sourceCapabilityIds,
    sourceTechnologyIds: result.sourceTechnologyIds,
    sourceIndustryIds: result.sourceIndustryIds,
    sourceExperienceIds: result.sourceExperienceIds,
    sourceKnowledgeArticleIds: result.sourceKnowledgeArticleIds,
    aiGeneratedAt: now.toDate().toISOString(),
  };
});

// ====================================================================
// AI Knowledge Extraction — Business Units round
// ====================================================================
//
// Upload -> Extract -> Review -> Approve. A document uploaded against a
// Project is sent to Gemini alongside the Company Knowledge Graph so it can
// extract structured project facts and, for each relationship it identifies
// (business unit/industry/technology/service/capability/product), cite only
// an ID that already exists in buildKnowledgeGraph()'s validIds — exactly
// the same "never invent an ID" mechanism generateProposalSection already
// uses. Nothing here ever creates a new Company Intelligence document; the
// result is written back as `aiExtracted*` fields on the `documents` doc
// for a human to review and selectively apply client-side
// (ProjectExtractionReviewScreen).

const PROJECT_EXTRACTION_RELATIONSHIP_FIELDS = [
  { field: "businessUnitIds", validKey: "businessUnitIds" },
  { field: "industryIds", validKey: "industryIds" },
  { field: "technologyIds", validKey: "technologyIds" },
  { field: "serviceIds", validKey: "serviceIds" },
  { field: "capabilityIds", validKey: "capabilityIds" },
  { field: "productIds", validKey: "productIds" },
];

/** Free-form narrative fields extracted verbatim from the document — validated as trimmed non-empty string arrays only, no ID checking. */
const PROJECT_EXTRACTION_TEXT_LIST_FIELDS = [
  "teamDisciplines",
  "deliverables",
  "equipment",
  "risks",
  "successFactors",
  "lessonsLearned",
  "certifications",
  "standards",
  "keyAchievements",
  "suggestedBusinessUnitNames",
  "suggestedIndustryNames",
  "suggestedServiceNames",
  "suggestedCapabilityNames",
];

/**
 * Calls Gemini with a text [prompt] plus one binary attachment (a project
 * document — PDF, image, or similar) and returns the raw parsed JSON
 * (unvalidated). Mirrors callGeminiForJson exactly, just with an extra
 * `inlineData` part — the first multimodal Gemini call in this codebase;
 * every prior AI feature only ever sent plain-text prompts because none of
 * them needed to read an uploaded file's actual content.
 */
async function callGeminiForJsonWithAttachment(prompt, { mimeType, data }) {
  const ai = genAiClient();
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: [
      {
        role: "user",
        parts: [{ text: prompt }, { inlineData: { mimeType, data } }],
      },
    ],
  });

  const text = response.text ?? "";
  if (!text.trim()) throw new Error("Empty response from model");

  return extractJson(text);
}

/** Builds the project-document extraction prompt given the knowledge graph context. */
function buildProjectExtractionPrompt({ knowledgeGraphText }) {
  return `You are a knowledge-extraction assistant for JV ALMA CIS. Read the
attached project document (an award letter, contract, technical/financial
proposal, completion certificate, capability statement, or similar) and
extract structured information about the project it describes.

You also have the company's internal knowledge graph below, each entry
prefixed with its unique ID in square brackets. When identifying which
Business Unit, Industry, Technology, Service, Capability, or Product this
project relates to, you MUST only reference entries that already exist in
this list, using their exact ID. If the document clearly describes
something with no match in the list below, do not invent an ID for it —
just omit it; a human will review the raw document separately.

${knowledgeGraphText}

This document may be a past-performance record rather than a forward-looking
proposal — a CPAR (Contractor Performance Assessment Report), final
evaluation, completion certificate, award/contract summary, or similar.
When it is:
- Treat it as a COMPLETED project. If it describes a finished contract
  (final evaluation, CPAR, completion certificate) and gives no evidence
  work is still ongoing, prefer the actual/final completion date over any
  planned/estimated one.
- Prefer dates from a stated "Period of Performance," "Actual Completion
  Date," or "Estimated Completion Date" over any date only implied by
  context.
- Read the contract value's currency from its symbol/code as written
  ($ = USD unless the document says otherwise, € = EUR, KES = Kenyan
  Shilling, etc.) — do not assume USD by default.
- "client" is the customer, contracting office, or end-user organization the
  work was actually delivered to/for — the counterparty on the
  contract/award, not the document's author or the report's recipient if
  those differ.
- "fundingAgency" is who financed or funded the contract when that is a
  distinct party from the client — e.g. AICS, USG/DOS, World Bank, an
  embassy program funder. On CPARs and similar US Government-style
  documents, still set fundingAgency explicitly when the document implies a
  US Government or other named funding agency, even if it also reads like
  the client. Leave fundingAgency null when the document gives no separate
  funder distinct from the client — never invent one.
- Summarize the work performed as concrete "deliverables" (what was
  actually built/delivered), not marketing language, and give a short
  1-3 sentence factual "description" of the project as a whole.

For Business Unit / Industry / Technology / Service / Capability / Product,
always prefer matching an existing entry from the knowledge graph above and
returning its ID. Only when the document clearly describes a kind of work
with no adequate match in the list above, suggest a short, plain-language
NAME (not an ID — nothing here is a real entity yet) in the matching
"suggested*Names" field below, so a human can decide whether to create it.
Do not suggest a name that's just a reword of something already in the
list. Leave a suggestion list empty rather than padding it.

Prioritize finding, in this order: (1) contract value + currency, (2)
funding/contracting agency, (3) scope of works / deliverables, (4) title,
client, location, dates, and completion status, (5) relationships and
narrative detail. Earlier items matter more to get right than later ones.

Return ONLY a JSON object of the form:
{
  "projectTitle": string | null,
  "description": string | null (1-3 sentence factual summary of the project),
  "contractValueAmount": number | null,
  "contractValueCurrency": string | null (ISO code if identifiable, e.g. "USD"),
  "fundingAgency": string | null (funder/financing agency, distinct from client — see rule above),
  "client": string | null,
  "country": string | null,
  "location": string | null,
  "contractDuration": string | null (free text, e.g. "18 months"),
  "startDate": string | null (ISO 8601 date, e.g. "2023-04-01"),
  "completionDate": string | null (ISO 8601 date),
  "businessUnitIds": string[] (IDs from the Business Units list above, or []),
  "industryIds": string[] (IDs from the Industries list above, or []),
  "technologyIds": string[] (IDs from the Technologies list above, or []),
  "serviceIds": string[] (IDs from the Services list above, or []),
  "capabilityIds": string[] (IDs from the Capabilities list above, or []),
  "productIds": string[] (IDs from the Products list above, or []),
  "suggestedBusinessUnitNames": string[] (plain names, only if no adequate match above, or []),
  "suggestedIndustryNames": string[] (plain names, only if no adequate match above, or []),
  "suggestedServiceNames": string[] (plain names, only if no adequate match above, or []),
  "suggestedCapabilityNames": string[] (plain names, only if no adequate match above, or []),
  "teamDisciplines": string[] (roles/disciplines involved, e.g. "Structural Engineer"),
  "deliverables": string[],
  "equipment": string[] (equipment/plant used or supplied),
  "risks": string[] (risks noted or encountered),
  "successFactors": string[] (what made the project succeed),
  "lessonsLearned": string[],
  "certifications": string[] (certifications held or achieved),
  "standards": string[] (technical/quality standards referenced),
  "keyAchievements": string[]
}
Only extract what the document actually states or clearly implies — never
fabricate a value. Use null/[] for anything not present. No commentary, no
markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validation layer for project-document extraction — same philosophy as
 * validateProposalSectionGeneration: every relationship-suggestion ID is
 * filtered down to IDs that actually exist in [validIds] (this is what
 * makes "never duplicate/invent entities" true by construction, not just by
 * prompt instruction), narrative fields are trimmed non-empty strings only.
 * Unlike proposal-section generation there is no single required field — a
 * document may only yield a handful of the ~20 fields, and that's still a
 * valid, useful partial result for a human to review.
 */
function validateProjectExtraction(parsed, validIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Project extraction response was not a JSON object");
  }

  const str = (v) => (typeof v === "string" && v.trim() ? v.trim() : null);
  const num = (v) => {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  };
  const isoDate = (v) => {
    if (typeof v !== "string" || !v.trim()) return null;
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  };

  const result = {
    projectTitle: str(parsed.projectTitle),
    description: str(parsed.description),
    client: str(parsed.client),
    fundingAgency: str(parsed.fundingAgency),
    country: str(parsed.country),
    location: str(parsed.location),
    contractValueAmount: num(parsed.contractValueAmount),
    contractValueCurrency: str(parsed.contractValueCurrency),
    contractDuration: str(parsed.contractDuration),
    startDate: isoDate(parsed.startDate),
    completionDate: isoDate(parsed.completionDate),
  };

  for (const { field, validKey } of PROJECT_EXTRACTION_RELATIONSHIP_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    const valid = validIds[validKey] || new Set();
    result[field] = raw.filter((id) => typeof id === "string" && valid.has(id));
  }

  for (const field of PROJECT_EXTRACTION_TEXT_LIST_FIELDS) {
    const raw = Array.isArray(parsed[field]) ? parsed[field] : [];
    result[field] = raw
      .filter((s) => typeof s === "string" && s.trim().length > 0)
      .map((s) => s.trim());
  }

  return result;
}

/**
 * Callable: extractProjectDocumentKnowledge — { documentId: string }
 * Downloads the document's file from Firebase Storage, sends it to Gemini
 * alongside the Company Knowledge Graph, and writes the extracted fields
 * directly onto the `documents` document as `aiExtracted*` fields with
 * `aiExtractionStatus: "extracted"` — awaiting human review
 * (ProjectExtractionReviewScreen). First function in this app to read
 * Firebase Storage or send a file to Gemini; every prior AI feature only
 * ever read Firestore text fields.
 */
/**
 * Best-effort MIME inference from a file name/path, used only as a fallback
 * when Firestore's `contentType` is missing or the generic
 * "application/octet-stream" fallback the client falls back to for
 * extensions it doesn't recognize (see `_guessMimeType` in
 * upload_project_document_dialog.dart / import_project_from_document_dialog.dart).
 * Gemini rejects octet-stream outright, so this gives already-uploaded
 * documents with a stale/generic contentType a chance to still extract
 * without requiring re-upload.
 */
function guessMimeFromPath(pathOrName) {
  const name = (pathOrName || "").toLowerCase();
  if (name.endsWith(".pdf")) return "application/pdf";
  if (name.endsWith(".png")) return "image/png";
  if (name.endsWith(".jpg") || name.endsWith(".jpeg")) return "image/jpeg";
  if (name.endsWith(".webp")) return "image/webp";
  if (name.endsWith(".heic")) return "image/heic";
  if (name.endsWith(".txt")) return "text/plain";
  if (name.endsWith(".doc")) return "application/msword";
  if (name.endsWith(".docx")) {
    return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
  }
  if (name.endsWith(".xls")) return "application/vnd.ms-excel";
  if (name.endsWith(".xlsx")) {
    return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
  }
  return null;
}

exports.extractProjectDocumentKnowledge = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { documentId } = request.data || {};
  if (!documentId) throw new HttpsError("invalid-argument", "documentId is required");

  const docRef = db.collection("documents").doc(documentId);
  const docSnap = await docRef.get();
  if (!docSnap.exists) throw new HttpsError("not-found", "Document not found");
  const doc = docSnap.data();
  if (!doc.storagePath) {
    throw new HttpsError("failed-precondition", "Document has no uploaded file yet");
  }

  const [fileBuffer] = await admin.storage().bucket().file(doc.storagePath).download();
  const data = fileBuffer.toString("base64");
  let mimeType = doc.contentType || "application/octet-stream";
  if (!mimeType || mimeType === "application/octet-stream") {
    mimeType = guessMimeFromPath(doc.fileName) || guessMimeFromPath(doc.storagePath) || mimeType;
  }
  if (mimeType === "application/octet-stream") {
    throw new HttpsError(
      "failed-precondition",
      "Unsupported file type for AI extraction. Please upload a PDF, PNG, JPEG, or text file.",
    );
  }

  const { text: knowledgeGraphText, validIds } = await buildKnowledgeGraph();
  const prompt = buildProjectExtractionPrompt({ knowledgeGraphText });

  let result;
  try {
    result = await retryAsync(
      async () =>
        validateProjectExtraction(
          await callGeminiForJsonWithAttachment(prompt, { mimeType, data }),
          validIds,
        ),
      { label: "extractProjectDocumentKnowledge" },
    );
  } catch (e) {
    logger.error("extractProjectDocumentKnowledge: all attempts failed", e);
    throw new HttpsError("internal", "AI project knowledge extraction failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  const toTimestamp = (iso) => (iso ? admin.firestore.Timestamp.fromDate(new Date(iso)) : null);

  await docRef.update({
    aiExtractionStatus: "extracted",
    aiExtractedAt: now,
    aiExtractedProjectTitle: result.projectTitle,
    aiExtractedDescription: result.description,
    aiExtractedClient: result.client,
    aiExtractedFundingAgency: result.fundingAgency,
    aiExtractedCountry: result.country,
    aiExtractedLocation: result.location,
    aiExtractedContractValueAmount: result.contractValueAmount,
    aiExtractedContractValueCurrency: result.contractValueCurrency,
    aiExtractedContractDuration: result.contractDuration,
    aiExtractedStartDate: toTimestamp(result.startDate),
    aiExtractedCompletionDate: toTimestamp(result.completionDate),
    aiExtractedBusinessUnitIds: result.businessUnitIds,
    aiExtractedIndustryIds: result.industryIds,
    aiExtractedTechnologyIds: result.technologyIds,
    aiExtractedServiceIds: result.serviceIds,
    aiExtractedCapabilityIds: result.capabilityIds,
    aiExtractedProductIds: result.productIds,
    aiSuggestedBusinessUnitNames: result.suggestedBusinessUnitNames,
    aiSuggestedIndustryNames: result.suggestedIndustryNames,
    aiSuggestedServiceNames: result.suggestedServiceNames,
    aiSuggestedCapabilityNames: result.suggestedCapabilityNames,
    aiExtractedTeamDisciplines: result.teamDisciplines,
    aiExtractedDeliverables: result.deliverables,
    aiExtractedEquipment: result.equipment,
    aiExtractedRisks: result.risks,
    aiExtractedSuccessFactors: result.successFactors,
    aiExtractedLessonsLearned: result.lessonsLearned,
    aiExtractedCertifications: result.certifications,
    aiExtractedStandards: result.standards,
    aiExtractedKeyAchievements: result.keyAchievements,
    updatedAt: now,
  });

  return { aiExtractedAt: now.toDate().toISOString(), ...result };
});

/**
 * Summarizes one Business Unit's own linked products/services/technologies/
 * industries/experiences/projects for the expertise-summary prompt — a
 * narrower, single-entity slice of company data than buildKnowledgeGraph()
 * (which returns the *whole* graph). Capabilities are deliberately not
 * queried here (unlike the knowledge graph, `Capability` has no direct
 * `businessUnitIds` field — the app derives that relationship transitively
 * client-side via Product/Service IDs; not worth re-deriving server-side
 * for a short summary).
 */
async function buildBusinessUnitContext(businessUnitId) {
  const [
    businessUnitSnap,
    productsSnap,
    servicesSnap,
    technologiesSnap,
    industriesSnap,
    experiencesSnap,
    projectsSnap,
  ] = await Promise.all([
    db.collection("businessUnits").doc(businessUnitId).get(),
    db.collection("products").where("businessUnitId", "==", businessUnitId).limit(50).get(),
    db.collection("services").where("businessUnitIds", "array-contains", businessUnitId).limit(50).get(),
    db.collection("technologies").where("businessUnitIds", "array-contains", businessUnitId).limit(50).get(),
    db.collection("industries").where("businessUnitIds", "array-contains", businessUnitId).limit(50).get(),
    db.collection("experiences").where("businessUnitIds", "array-contains", businessUnitId).limit(50).get(),
    db.collection("projects").where("businessUnitIds", "array-contains", businessUnitId).limit(50).get(),
  ]);

  if (!businessUnitSnap.exists) return null;
  const businessUnit = businessUnitSnap.data();

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Business Unit: ${businessUnit.name}\n${businessUnit.summary || businessUnit.description || ""}`,
    `Products:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Services:\n${list(servicesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries served:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Past experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { businessUnit, text };
}

function buildBusinessUnitSummaryPrompt({ contextText }) {
  return `You are summarizing one business unit's expertise for an internal
executive dashboard, based only on the company's own recorded data below —
never invent achievements or claims not supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateBusinessUnitSummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Business unit summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Business unit summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateBusinessUnitSummary — { businessUnitId: string }
 * Writes a short "AI summary of expertise" + highlight bullets onto the
 * `businessUnits` document, for the Business Unit Workspace header.
 */
exports.generateBusinessUnitSummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { businessUnitId } = request.data || {};
  if (!businessUnitId) throw new HttpsError("invalid-argument", "businessUnitId is required");

  const context = await buildBusinessUnitContext(businessUnitId);
  if (!context) throw new HttpsError("not-found", "Business unit not found");

  const prompt = buildBusinessUnitSummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateBusinessUnitSummary(await callGeminiForJson(prompt)),
      { label: "generateBusinessUnitSummary" },
    );
  } catch (e) {
    logger.error("generateBusinessUnitSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI business unit summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("businessUnits").doc(businessUnitId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Product's own linked capabilities/technologies/industries/
 * experiences/projects for the expertise-summary prompt — mirrors
 * `buildBusinessUnitContext` one level down the Company Intelligence graph.
 * Unlike Business Unit (which reverse-queries products/services/
 * technologies/industries by `businessUnitId`/`businessUnitIds`), Product
 * *forward*-owns its `capabilityIds`/`industryIds`/`technologyIds`, so those
 * three are resolved by document ID instead of an array-contains query;
 * past projects and experiences still don't have a forward list on Product
 * itself, so those two stay reverse-queried via their own `productIds`.
 */
async function buildProductContext(productId) {
  const productSnap = await db.collection("products").doc(productId).get();
  if (!productSnap.exists) return null;
  const product = productSnap.data();

  const capabilityIds = (product.capabilityIds || []).slice(0, 30);
  const industryIds = (product.industryIds || []).slice(0, 30);
  const technologyIds = (product.technologyIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });

  const [
    businessUnitSnap,
    capabilitiesSnap,
    industriesSnap,
    technologiesSnap,
    experiencesSnap,
    projectsSnap,
  ] = await Promise.all([
    product.businessUnitId
      ? db.collection("businessUnits").doc(product.businessUnitId).get()
      : Promise.resolve(null),
    byIds("capabilities", capabilityIds),
    byIds("industries", industryIds),
    byIds("technologies", technologyIds),
    db.collection("experiences").where("productIds", "array-contains", productId).limit(50).get(),
    db.collection("projects").where("productIds", "array-contains", productId).limit(50).get(),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Product: ${product.name}\n${product.summary || product.description || ""}`,
    `Business Unit: ${businessUnitSnap && businessUnitSnap.exists ? businessUnitSnap.data().name : "unspecified"}`,
    `Capabilities:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries served:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Past experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { product, text };
}

function buildProductSummaryPrompt({ contextText }) {
  return `You are summarizing one product's market positioning for an internal
executive dashboard, based only on the company's own recorded data below —
never invent achievements or claims not supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateProductSummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Product summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Product summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateProductSummary — { productId: string }
 * Writes a short "AI summary of positioning" + highlight bullets onto the
 * `products` document, for the Product Workspace header. Mirrors
 * `generateBusinessUnitSummary` exactly.
 */
exports.generateProductSummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { productId } = request.data || {};
  if (!productId) throw new HttpsError("invalid-argument", "productId is required");

  const context = await buildProductContext(productId);
  if (!context) throw new HttpsError("not-found", "Product not found");

  const prompt = buildProductSummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateProductSummary(await callGeminiForJson(prompt)),
      { label: "generateProductSummary" },
    );
  } catch (e) {
    logger.error("generateProductSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI product summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("products").doc(productId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Service's own linked capabilities/industries/business
 * units/projects for the expertise-summary prompt — mirrors
 * `buildProductContext`. Service forward-owns `capabilityIds`/
 * `industryIds`/`businessUnitIds` (plural — a service can belong to more
 * than one business unit, unlike Product's single `businessUnitId`), so all
 * three are resolved by document ID. There's no Experience section here:
 * unlike Product, `Experience` has no `serviceIds` field to reverse-query,
 * so Services skip that part of the context entirely rather than
 * referencing a field that doesn't exist.
 */
async function buildServiceContext(serviceId) {
  const serviceSnap = await db.collection("services").doc(serviceId).get();
  if (!serviceSnap.exists) return null;
  const service = serviceSnap.data();

  const capabilityIds = (service.capabilityIds || []).slice(0, 30);
  const industryIds = (service.industryIds || []).slice(0, 30);
  const businessUnitIds = (service.businessUnitIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });

  const [businessUnitsSnap, capabilitiesSnap, industriesSnap, projectsSnap] = await Promise.all([
    byIds("businessUnits", businessUnitIds),
    byIds("capabilities", capabilityIds),
    byIds("industries", industryIds),
    db.collection("projects").where("serviceIds", "array-contains", serviceId).limit(50).get(),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Service: ${service.name}\n${service.summary || service.description || ""}`,
    `Business Units:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Capabilities:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries served:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { service, text };
}

function buildServiceSummaryPrompt({ contextText }) {
  return `You are summarizing one service's market positioning for an internal
executive dashboard, based only on the company's own recorded data below —
never invent achievements or claims not supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateServiceSummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Service summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Service summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateServiceSummary — { serviceId: string }
 * Writes a short "AI summary of positioning" + highlight bullets onto the
 * `services` document, for the Service Workspace header. Mirrors
 * `generateProductSummary` exactly.
 */
exports.generateServiceSummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { serviceId } = request.data || {};
  if (!serviceId) throw new HttpsError("invalid-argument", "serviceId is required");

  const context = await buildServiceContext(serviceId);
  if (!context) throw new HttpsError("not-found", "Service not found");

  const prompt = buildServiceSummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateServiceSummary(await callGeminiForJson(prompt)),
      { label: "generateServiceSummary" },
    );
  } catch (e) {
    logger.error("generateServiceSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI service summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("services").doc(serviceId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Capability's application across the company for the
 * expertise-summary prompt — mirrors `buildServiceContext`. Unlike
 * Product/Service, Capability only forward-owns `productIds`/`serviceIds`;
 * everything else that references a capability (business units,
 * technologies, industries, experiences, projects) does so via its own
 * `capabilityIds` field, so those five are reverse-queried instead.
 */
async function buildCapabilityContext(capabilityId) {
  const capabilitySnap = await db.collection("capabilities").doc(capabilityId).get();
  if (!capabilitySnap.exists) return null;
  const capability = capabilitySnap.data();

  const productIds = (capability.productIds || []).slice(0, 30);
  const serviceIds = (capability.serviceIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });
  const byArrayContains = (collection) =>
    db.collection(collection).where("capabilityIds", "array-contains", capabilityId).limit(50).get();

  const [
    productsSnap,
    servicesSnap,
    businessUnitsSnap,
    technologiesSnap,
    industriesSnap,
    experiencesSnap,
    projectsSnap,
  ] = await Promise.all([
    byIds("products", productIds),
    byIds("services", serviceIds),
    byArrayContains("businessUnits"),
    byArrayContains("technologies"),
    byArrayContains("industries"),
    byArrayContains("experiences"),
    byArrayContains("projects"),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Capability: ${capability.name}\n${capability.summary || capability.description || ""}`,
    `Business Units using it:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Products using it:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Services using it:\n${list(servicesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries served:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Past experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { capability, text };
}

function buildCapabilitySummaryPrompt({ contextText }) {
  return `You are summarizing one internal capability's application across
the company for an internal executive dashboard, based only on the
company's own recorded data below — never invent achievements or claims not
supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateCapabilitySummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Capability summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Capability summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateCapabilitySummary — { capabilityId: string }
 * Writes a short "AI summary of application" + highlight bullets onto the
 * `capabilities` document, for the Capability Workspace header. Mirrors
 * `generateServiceSummary`/`generateProductSummary` exactly.
 */
exports.generateCapabilitySummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { capabilityId } = request.data || {};
  if (!capabilityId) throw new HttpsError("invalid-argument", "capabilityId is required");

  const context = await buildCapabilityContext(capabilityId);
  if (!context) throw new HttpsError("not-found", "Capability not found");

  const prompt = buildCapabilitySummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateCapabilitySummary(await callGeminiForJson(prompt)),
      { label: "generateCapabilitySummary" },
    );
  } catch (e) {
    logger.error("generateCapabilitySummary: all attempts failed", e);
    throw new HttpsError("internal", "AI capability summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("capabilities").doc(capabilityId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Technology's application across the company for the
 * expertise-summary prompt — mirrors `buildCapabilityContext`. Technology
 * forward-owns `businessUnitIds`/`productIds`/`capabilityIds`, resolved by
 * document ID; industries/experiences/projects reference it via their own
 * `technologyIds` field, so those three are reverse-queried instead.
 */
async function buildTechnologyContext(technologyId) {
  const technologySnap = await db.collection("technologies").doc(technologyId).get();
  if (!technologySnap.exists) return null;
  const technology = technologySnap.data();

  const businessUnitIds = (technology.businessUnitIds || []).slice(0, 30);
  const productIds = (technology.productIds || []).slice(0, 30);
  const capabilityIds = (technology.capabilityIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });
  const byArrayContains = (collection) =>
    db.collection(collection).where("technologyIds", "array-contains", technologyId).limit(50).get();

  const [
    businessUnitsSnap,
    productsSnap,
    capabilitiesSnap,
    industriesSnap,
    experiencesSnap,
    projectsSnap,
  ] = await Promise.all([
    byIds("businessUnits", businessUnitIds),
    byIds("products", productIds),
    byIds("capabilities", capabilityIds),
    byArrayContains("industries"),
    byArrayContains("experiences"),
    byArrayContains("projects"),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Technology: ${technology.name}\n${technology.summary || technology.description || ""}`,
    `Business Units using it:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Products using it:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Capabilities enabled:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries served:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Past experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { technology, text };
}

function buildTechnologySummaryPrompt({ contextText }) {
  return `You are summarizing one technology's application across the company
for an internal executive dashboard, based only on the company's own
recorded data below — never invent achievements or claims not supported by
it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateTechnologySummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Technology summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Technology summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateTechnologySummary — { technologyId: string }
 * Writes a short "AI summary of application" + highlight bullets onto the
 * `technologies` document, for the Technology Workspace header. Mirrors
 * `generateCapabilitySummary` exactly.
 */
exports.generateTechnologySummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { technologyId } = request.data || {};
  if (!technologyId) throw new HttpsError("invalid-argument", "technologyId is required");

  const context = await buildTechnologyContext(technologyId);
  if (!context) throw new HttpsError("not-found", "Technology not found");

  const prompt = buildTechnologySummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateTechnologySummary(await callGeminiForJson(prompt)),
      { label: "generateTechnologySummary" },
    );
  } catch (e) {
    logger.error("generateTechnologySummary: all attempts failed", e);
    throw new HttpsError("internal", "AI technology summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("technologies").doc(technologyId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Industry's application across the company for the
 * expertise-summary prompt — mirrors `buildTechnologyContext`. Industry
 * forward-owns all five of its relationships (`businessUnitIds`/
 * `productIds`/`capabilityIds`/`technologyIds`/`experienceIds`), so all are
 * resolved by document ID; only knowledge articles and projects reference
 * it via their own `industryIds` field, so those two are reverse-queried.
 */
async function buildIndustryContext(industryId) {
  const industrySnap = await db.collection("industries").doc(industryId).get();
  if (!industrySnap.exists) return null;
  const industry = industrySnap.data();

  const businessUnitIds = (industry.businessUnitIds || []).slice(0, 30);
  const productIds = (industry.productIds || []).slice(0, 30);
  const capabilityIds = (industry.capabilityIds || []).slice(0, 30);
  const technologyIds = (industry.technologyIds || []).slice(0, 30);
  const experienceIds = (industry.experienceIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });

  const [
    businessUnitsSnap,
    productsSnap,
    capabilitiesSnap,
    technologiesSnap,
    experiencesSnap,
    projectsSnap,
  ] = await Promise.all([
    byIds("businessUnits", businessUnitIds),
    byIds("products", productIds),
    byIds("capabilities", capabilityIds),
    byIds("technologies", technologyIds),
    byIds("experiences", experienceIds),
    db.collection("projects").where("industryIds", "array-contains", industryId).limit(50).get(),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));

  const text = [
    `Industry: ${industry.name}\n${industry.description || ""}`,
    `Business Units serving it:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Products used:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Capabilities applied:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies applied:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Past experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
    `Projects:\n${list(projectsSnap, (d) => `- ${d.data().name} (${d.data().status}) for ${d.data().client || "unspecified client"}`)}`,
  ].join("\n\n");

  return { industry, text };
}

function buildIndustrySummaryPrompt({ contextText }) {
  return `You are summarizing the company's track record in one industry
vertical for an internal executive dashboard, based only on the company's
own recorded data below — never invent achievements or claims not
supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown),
  "highlights": string[] (3-5 short bullet points naming concrete strengths)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateIndustrySummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Industry summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Industry summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateIndustrySummary — { industryId: string }
 * Writes a short "AI summary of application" + highlight bullets onto the
 * `industries` document, for the Industry Workspace header. Mirrors
 * `generateTechnologySummary` exactly.
 */
exports.generateIndustrySummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { industryId } = request.data || {};
  if (!industryId) throw new HttpsError("invalid-argument", "industryId is required");

  const context = await buildIndustryContext(industryId);
  if (!context) throw new HttpsError("not-found", "Industry not found");

  const prompt = buildIndustrySummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateIndustrySummary(await callGeminiForJson(prompt)),
      { label: "generateIndustrySummary" },
    );
  } catch (e) {
    logger.error("generateIndustrySummary: all attempts failed", e);
    throw new HttpsError("internal", "AI industry summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("industries").doc(industryId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Experience — its own outcome/achievements/lessons-learned
 * plus its resolved graph context — into a polished executive narrative.
 * Unlike the other five Company Intelligence workspaces, Experience
 * already carries rich narrative fields of its own, so this context
 * includes them directly rather than relying purely on relationship
 * lookups. Experience forward-owns all five of its relationships, so all
 * five are resolved by document ID; only knowledge articles and the
 * "promoted from" project are reverse-queried (the latter via
 * `Project.experienceId`, a single-field equality check, not
 * array-contains, since one experience promotes from at most one project).
 */
async function buildExperienceContext(experienceId) {
  const experienceSnap = await db.collection("experiences").doc(experienceId).get();
  if (!experienceSnap.exists) return null;
  const experience = experienceSnap.data();

  const businessUnitIds = (experience.businessUnitIds || []).slice(0, 30);
  const productIds = (experience.productIds || []).slice(0, 30);
  const capabilityIds = (experience.capabilityIds || []).slice(0, 30);
  const technologyIds = (experience.technologyIds || []).slice(0, 30);
  const industryIds = (experience.industryIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });

  const [
    businessUnitsSnap,
    productsSnap,
    capabilitiesSnap,
    technologiesSnap,
    industriesSnap,
  ] = await Promise.all([
    byIds("businessUnits", businessUnitIds),
    byIds("products", productIds),
    byIds("capabilities", capabilityIds),
    byIds("technologies", technologyIds),
    byIds("industries", industryIds),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));
  const bullets = (arr) => (arr && arr.length ? arr.map((s) => `- ${s}`).join("\n") : "(none recorded)");

  const text = [
    `Experience: ${experience.title}\n${experience.summary || ""}`,
    `Client: ${experience.clientName || "unspecified"}${experience.partnerName ? ` (partner: ${experience.partnerName})` : ""}`,
    `Location: ${[experience.country, experience.region].filter(Boolean).join(", ") || "unspecified"}`,
    `Contract value: ${experience.contractValue ? `${experience.contractValue} ${experience.currency || ""}` : "not disclosed"}`,
    `Outcome: ${experience.outcome || "(not recorded)"}`,
    `Achievements:\n${bullets(experience.achievements)}`,
    `Lessons learned:\n${bullets(experience.lessonsLearned)}`,
    `Business Units involved:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Products used:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Capabilities applied:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies applied:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
  ].join("\n\n");

  return { experience, text };
}

function buildExperienceSummaryPrompt({ contextText }) {
  return `You are turning one completed engagement's raw record into a
polished, reusable executive narrative for an internal Company Intelligence
dashboard, based only on the company's own recorded data below — never
invent achievements, outcomes, or claims not supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown,
    synthesizing the outcome and what it demonstrates about the company),
  "highlights": string[] (3-5 short bullet points naming concrete strengths
    or achievements this experience demonstrates)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateExperienceSummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Experience summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Experience summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateExperienceSummary — { experienceId: string }
 * Writes a short executive narrative + highlight bullets onto the
 * `experiences` document, for the Experience Workspace header. Mirrors
 * `generateIndustrySummary` exactly.
 */
exports.generateExperienceSummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { experienceId } = request.data || {};
  if (!experienceId) throw new HttpsError("invalid-argument", "experienceId is required");

  const context = await buildExperienceContext(experienceId);
  if (!context) throw new HttpsError("not-found", "Experience not found");

  const prompt = buildExperienceSummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateExperienceSummary(await callGeminiForJson(prompt)),
      { label: "generateExperienceSummary" },
    );
  } catch (e) {
    logger.error("generateExperienceSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI experience summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("experiences").doc(experienceId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

/**
 * Summarizes one Knowledge Article's practical relevance across the
 * company for the expertise-summary prompt — mirrors
 * `buildExperienceContext`. KnowledgeArticle forward-owns all seven
 * Company Intelligence relationship types (the only entity in the graph
 * that does), so every related-entity section resolves by document ID —
 * no reverse queries anywhere in this context builder. [content] is
 * truncated defensively before being sent to the model; articles can run
 * long and the prompt only needs enough to ground the summary, not the
 * full text verbatim.
 */
async function buildKnowledgeArticleContext(articleId) {
  const articleSnap = await db.collection("knowledgeBase").doc(articleId).get();
  if (!articleSnap.exists) return null;
  const article = articleSnap.data();

  const businessUnitIds = (article.businessUnitIds || []).slice(0, 30);
  const productIds = (article.productIds || []).slice(0, 30);
  const serviceIds = (article.serviceIds || []).slice(0, 30);
  const capabilityIds = (article.capabilityIds || []).slice(0, 30);
  const technologyIds = (article.technologyIds || []).slice(0, 30);
  const industryIds = (article.industryIds || []).slice(0, 30);
  const experienceIds = (article.experienceIds || []).slice(0, 30);
  const byIds = (collection, ids) =>
    ids.length
      ? db.collection(collection).where(admin.firestore.FieldPath.documentId(), "in", ids).get()
      : Promise.resolve({ empty: true, docs: [] });

  const [
    businessUnitsSnap,
    productsSnap,
    servicesSnap,
    capabilitiesSnap,
    technologiesSnap,
    industriesSnap,
    experiencesSnap,
  ] = await Promise.all([
    byIds("businessUnits", businessUnitIds),
    byIds("products", productIds),
    byIds("services", serviceIds),
    byIds("capabilities", capabilityIds),
    byIds("technologies", technologyIds),
    byIds("industries", industryIds),
    byIds("experiences", experienceIds),
  ]);

  const list = (snap, fn) => (snap.empty ? "(none recorded)" : snap.docs.map(fn).join("\n"));
  const truncatedContent = (article.content || "").slice(0, 4000);

  const text = [
    `Knowledge Article: ${article.title}${article.category ? ` (${article.category})` : ""}\n${article.summary || ""}`,
    `Content excerpt:\n${truncatedContent || "(no content recorded)"}`,
    `Business Units:\n${list(businessUnitsSnap, (d) => `- ${d.data().name}`)}`,
    `Products:\n${list(productsSnap, (d) => `- ${d.data().name}`)}`,
    `Services:\n${list(servicesSnap, (d) => `- ${d.data().name}`)}`,
    `Capabilities:\n${list(capabilitiesSnap, (d) => `- ${d.data().name}`)}`,
    `Technologies:\n${list(technologiesSnap, (d) => `- ${d.data().name}`)}`,
    `Industries:\n${list(industriesSnap, (d) => `- ${d.data().name}`)}`,
    `Related experiences:\n${list(experiencesSnap, (d) => `- ${d.data().title}: ${d.data().outcome || ""}`)}`,
  ].join("\n\n");

  return { article, text };
}

function buildKnowledgeArticleSummaryPrompt({ contextText }) {
  return `You are summarizing one internal knowledge article's practical
relevance across the company for an internal executive dashboard, based
only on the company's own recorded data below — never invent claims not
supported by it.

${contextText}

Return ONLY a JSON object of the form:
{
  "summary": string (2-4 sentences, plain executive language, no markdown,
    explaining what this article covers and where it's most applicable),
  "highlights": string[] (3-5 short bullet points naming concrete use cases
    or applications)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

function validateKnowledgeArticleSummary(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Knowledge article summary response was not a JSON object");
  }
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) throw new Error("Knowledge article summary response had no summary");
  const highlights = Array.isArray(parsed.highlights)
    ? parsed.highlights.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim())
    : [];
  return { summary, highlights };
}

/**
 * Callable: generateKnowledgeArticleSummary — { articleId: string }
 * Writes a short "practical relevance" narrative + highlight bullets onto
 * the `knowledgeBase` document, for the Knowledge Article Workspace
 * header. Mirrors `generateExperienceSummary` exactly.
 */
exports.generateKnowledgeArticleSummary = onCall({ timeoutSeconds: 60 }, async (request) => {
  const { articleId } = request.data || {};
  if (!articleId) throw new HttpsError("invalid-argument", "articleId is required");

  const context = await buildKnowledgeArticleContext(articleId);
  if (!context) throw new HttpsError("not-found", "Knowledge article not found");

  const prompt = buildKnowledgeArticleSummaryPrompt({ contextText: context.text });

  let result;
  try {
    result = await retryAsync(
      async () => validateKnowledgeArticleSummary(await callGeminiForJson(prompt)),
      { label: "generateKnowledgeArticleSummary" },
    );
  } catch (e) {
    logger.error("generateKnowledgeArticleSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI knowledge article summary failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("knowledgeBase").doc(articleId).update({
    aiExpertiseSummary: result.summary,
    aiExpertiseHighlights: result.highlights,
    aiExpertiseSummaryGeneratedAt: now,
    updatedAt: now,
  });

  return {
    summary: result.summary,
    highlights: result.highlights,
    generatedAt: now.toDate().toISOString(),
  };
});

// ====================================================================
// Milestone 5.1 — Executive Dashboard: AI Executive Summary
// ====================================================================
//
// Reuses buildKnowledgeGraph/buildOpportunityPortfolioSummary/
// callGeminiForJson/retryAsync unchanged, exactly as generateRecommendations
// does. Adds one small new summary builder (buildProposalPortfolioSummary)
// so the prompt also sees proposal-authoring status (draft/ready-for-review)
// alongside opportunity-level state, since "which proposals are blocked" is
// part of the brief's example narrative. Writes to a single document —
// analytics/executiveSummary — rather than a collection, since the whole
// company has exactly one current summary at a time (see ADR-009 /
// ExecutiveSummary model doc comment).

const EXECUTIVE_INSIGHT_SEVERITY_VALUES = ["info", "watch", "risk"];

/** Summarizes every proposal's authoring status for the executive-summary prompt. */
async function buildProposalPortfolioSummary() {
  const snap = await db.collection("proposals").limit(100).get();

  const lines = snap.docs.map((d) => {
    const p = d.data();
    const parts = [
      `[${d.id}] "${p.title}"`,
      `status: ${p.status || "draft"}`,
      `opportunityId: ${p.opportunityId}`,
    ];
    if (p.readyForReviewAt) {
      parts.push(`readyForReviewAt: ${p.readyForReviewAt.toDate().toISOString().slice(0, 10)}`);
    }
    return `- ${parts.join(" | ")}`;
  });

  return lines.length ? lines.join("\n") : "(no proposals started yet)";
}

/** Builds the executive-summary prompt given knowledge graph + opportunity + proposal context. */
function buildExecutiveSummaryPrompt({ knowledgeGraphText, portfolioText, proposalsText }) {
  return `You are a business-intelligence assistant producing a portfolio-wide
executive summary for JV ALMA CIS leadership. You know the company's internal
knowledge graph, the current state of every opportunity in the pipeline, and
the authoring status of every proposal, all listed below with unique IDs in
square brackets. When referencing an opportunity you MUST use its exact ID
and no other. Never invent an ID that isn't listed.

Company knowledge graph:
${knowledgeGraphText}

Opportunity portfolio:
${portfolioText}

Proposal portfolio:
${proposalsText}

Reason across all three sections — do not perform keyword matching — to
produce a short executive narrative plus a handful of specific, prioritized
insights leadership should know about right now. Every insight must explain
WHY, citing specific evidence (business unit/industry concentration, stalled
proposals, deadlines, risk levels, confidence scores, etc.) rather than
restating raw numbers.

Return ONLY a JSON object of the form:
{
  "narrative": string (3-5 sentences, the kind of summary a CEO would read
    first thing Monday morning — where the pipeline is strong, where it's
    weak, and what's most urgent),
  "insights": [
    {
      "title": string (a short, specific headline, 4-10 words),
      "reasoning": string (2-3 sentences explaining WHY, citing specific
        evidence from the data above),
      "severity": "info" | "watch" | "risk",
      "relatedOpportunityIds": string[] (IDs from the opportunity portfolio
        above, or [])
    }
  ] (up to 6 insights, ordered most important first)
}
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

/**
 * Validates the executive-summary response. Unlike per-opportunity AI
 * passes, there's no reasonable partial result here — a summary with an
 * empty narrative isn't worth showing — so this throws (triggering
 * `retryAsync`'s retry path) rather than returning a defaulted object.
 * Each insight's `relatedOpportunityIds` is filtered against the real
 * opportunity IDs, the same "never a hallucinated reference" rule every
 * other AI feature in this file follows.
 */
function validateExecutiveSummary(parsed, opportunityIds) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Executive summary response was not a JSON object");
  }

  const narrative = typeof parsed.narrative === "string" ? parsed.narrative.trim() : "";
  if (!narrative) throw new Error("Executive summary response had an empty narrative");

  const rawInsights = Array.isArray(parsed.insights) ? parsed.insights : [];
  const insights = [];
  for (const item of rawInsights) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const title = typeof item.title === "string" ? item.title.trim() : "";
    const reasoning = typeof item.reasoning === "string" ? item.reasoning.trim() : "";
    if (!title || !reasoning) continue;

    insights.push({
      title,
      reasoning,
      severity: EXECUTIVE_INSIGHT_SEVERITY_VALUES.includes(item.severity) ? item.severity : "info",
      relatedOpportunityIds: Array.isArray(item.relatedOpportunityIds)
        ? item.relatedOpportunityIds.filter((id) => typeof id === "string" && opportunityIds.has(id))
        : [],
    });
  }

  return { narrative, insights: insights.slice(0, 6) };
}

/** Callable: generateExecutiveSummary -> { generatedAt: string } */
exports.generateExecutiveSummary = onCall({ timeoutSeconds: 120 }, async () => {
  const [{ text: knowledgeGraphText }, { text: portfolioText, validIds: opportunityIds }, proposalsText] =
    await Promise.all([
      buildKnowledgeGraph(),
      buildOpportunityPortfolioSummary(),
      buildProposalPortfolioSummary(),
    ]);

  const prompt = buildExecutiveSummaryPrompt({ knowledgeGraphText, portfolioText, proposalsText });

  let result;
  try {
    result = await retryAsync(
      async () => validateExecutiveSummary(await callGeminiForJson(prompt), opportunityIds),
      { label: "generateExecutiveSummary" },
    );
  } catch (e) {
    logger.error("generateExecutiveSummary: all attempts failed", e);
    throw new HttpsError("internal", "AI executive summary generation failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("analytics").doc("executiveSummary").set({
    narrative: result.narrative,
    insights: result.insights,
    generatedAt: now,
  });

  return { generatedAt: now.toDate().toISOString() };
});

// ====================================================================
// Milestone 4.4 — Submission Workspace: AI Submission Review
// ====================================================================
//
// Reuses buildKnowledgeGraph/buildRecommendationsContextForOpportunity/
// callGeminiForJson/retryAsync unchanged, exactly as generateProposalSection
// does. This is the first AI pass to also read every one of a proposal's own
// section contents plus its Document Library readiness (Milestone 4.3)
// alongside the usual opportunity intelligence chain.

const SUBMISSION_REVIEW_READINESS_VALUES = ["ready", "needsWork", "notReady"];
const RISK_LEVEL_VALUES = ["low", "medium", "high"];

/** Summarizes the documents linked to [proposalId] for the submission-review prompt. */
async function buildDocumentReadinessTextForProposal(proposalId) {
  const snap = await db
    .collection("documents")
    .where("relatedProposalIds", "array-contains", proposalId)
    .get();

  if (snap.empty) return "(no documents linked to this proposal yet)";

  return snap.docs
    .map((d) => {
      const doc = d.data();
      const expiry = doc.expiryDate ? doc.expiryDate.toDate().toISOString().slice(0, 10) : "no expiry";
      return `- [${doc.category || "other"}] "${doc.title}" — status: ${doc.status || "active"}, expiry: ${expiry}`;
    })
    .join("\n");
}

/** Builds the AI Submission Review prompt given the full reasoning chain. */
function buildSubmissionReviewPrompt({
  proposal,
  sections,
  opportunity,
  documentReadinessText,
  knowledgeGraphText,
  recommendationsText,
}) {
  const sectionsText = sections.length
    ? sections
        .map((s) => `- [${s.type}] "${s.title}" (status: ${s.status || "notStarted"}):\n${s.content || "(empty)"}`)
        .join("\n\n")
    : "(no sections yet)";

  return `You are a proposal submission reviewer for JV ALMA CIS, performing the
final compliance and quality check before a proposal is submitted to a
client. You reason using the company's full opportunity intelligence and
knowledge graph, this proposal's own section content, and its document
readiness, all below — never from titles alone.

Opportunity:
Title: ${opportunity.title}
Description: ${opportunity.description || "(no description provided)"}
Classification summary: ${opportunity.classificationSummary || "(not yet classified)"}
Match analysis: ${opportunity.strategicRecommendation || "(not yet analyzed)"}
Strategic review: ${opportunity.executiveSummary || "(not yet reviewed)"}

Active portfolio recommendations naming this opportunity:
${recommendationsText}

Company knowledge graph:
${knowledgeGraphText}

Proposal title: ${proposal.title}

Proposal sections:
${sectionsText}

Document Library readiness for this proposal:
${documentReadinessText}

Review this proposal as a whole and return ONLY a JSON object of the form:
{
  "overallReadiness": "ready" | "needsWork" | "notReady",
  "riskLevel": "low" | "medium" | "high" (risk of submitting as-is),
  "missingEvidence": string[] (specific evidence/claims that need supporting
    proof, each a self-contained sentence explaining what's missing and why
    it matters — or [] if none),
  "weakSections": string[] (which sections are weak and why, e.g. "Technical
    Approach: lacks quantified metrics" — or [] if none),
  "strongSections": string[] (which sections are strong and why — or []),
  "complianceConcerns": string[] (anything that could cause a compliance
    rejection, each explaining why — or []),
  "recommendedImprovements": string[] (specific, actionable improvements,
    each explaining why it would help — or [])
}
Every array item must be a complete, self-contained sentence that explains
WHY, not just a label. No commentary, no markdown fences, no explanation
outside the JSON object.`;
}

/**
 * Validation layer for the AI Submission Review — unlike ID-bearing AI
 * passes, there are no entity references to filter here (every field is
 * narrative text), so validation is just enum fallback + list sanitization,
 * the same "never trust the model's output directly" philosophy applied to
 * a text-only payload.
 */
function validateSubmissionReview(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Submission review response was not a JSON object");
  }

  const stringList = (value) =>
    Array.isArray(value)
      ? value.filter((v) => typeof v === "string" && v.trim()).map((v) => v.trim()).slice(0, 8)
      : [];

  return {
    overallReadiness: SUBMISSION_REVIEW_READINESS_VALUES.includes(parsed.overallReadiness)
      ? parsed.overallReadiness
      : "needsWork",
    riskLevel: RISK_LEVEL_VALUES.includes(parsed.riskLevel) ? parsed.riskLevel : "medium",
    missingEvidence: stringList(parsed.missingEvidence),
    weakSections: stringList(parsed.weakSections),
    strongSections: stringList(parsed.strongSections),
    complianceConcerns: stringList(parsed.complianceConcerns),
    recommendedImprovements: stringList(parsed.recommendedImprovements),
  };
}

/**
 * Callable: generateSubmissionReview — { proposalId: string }
 * Loads the proposal -> its sections -> its opportunity, builds the
 * knowledge graph + recommendations + document-readiness context, generates
 * the review via Gemini, and writes it directly onto the `proposals`
 * document — the live proposal stream picks that up on its own.
 */
exports.generateSubmissionReview = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { proposalId } = request.data || {};
  if (!proposalId) throw new HttpsError("invalid-argument", "proposalId is required");

  const proposalRef = db.collection("proposals").doc(proposalId);
  const proposalSnap = await proposalRef.get();
  if (!proposalSnap.exists) throw new HttpsError("not-found", "Proposal not found");
  const proposal = proposalSnap.data();

  const opportunitySnap = await db.collection("opportunities").doc(proposal.opportunityId).get();
  if (!opportunitySnap.exists) throw new HttpsError("not-found", "Opportunity not found");
  const opportunity = opportunitySnap.data();

  const sectionsSnap = await db
    .collection("proposalSections")
    .where("proposalId", "==", proposalId)
    .get();
  const sections = sectionsSnap.docs.map((d) => d.data());

  const [{ text: knowledgeGraphText }, recommendationsText, documentReadinessText] = await Promise.all([
    buildKnowledgeGraph(),
    buildRecommendationsContextForOpportunity(proposal.opportunityId),
    buildDocumentReadinessTextForProposal(proposalId),
  ]);

  const prompt = buildSubmissionReviewPrompt({
    proposal,
    sections,
    opportunity,
    documentReadinessText,
    knowledgeGraphText,
    recommendationsText,
  });

  let result;
  try {
    result = await retryAsync(
      async () => validateSubmissionReview(await callGeminiForJson(prompt)),
      { label: "generateSubmissionReview" },
    );
  } catch (e) {
    logger.error("generateSubmissionReview: all attempts failed", e);
    throw new HttpsError("internal", "AI submission review failed after retries");
  }

  const now = admin.firestore.Timestamp.now();
  await proposalRef.update({
    submissionReviewedAt: now,
    submissionReviewReadiness: result.overallReadiness,
    submissionReviewRiskLevel: result.riskLevel,
    submissionReviewMissingEvidence: result.missingEvidence,
    submissionReviewWeakSections: result.weakSections,
    submissionReviewStrongSections: result.strongSections,
    submissionReviewComplianceConcerns: result.complianceConcerns,
    submissionReviewRecommendedImprovements: result.recommendedImprovements,
    updatedAt: now,
  });

  return {
    overallReadiness: result.overallReadiness,
    riskLevel: result.riskLevel,
    missingEvidence: result.missingEvidence,
    weakSections: result.weakSections,
    strongSections: result.strongSections,
    complianceConcerns: result.complianceConcerns,
    recommendedImprovements: result.recommendedImprovements,
    reviewedAt: now.toDate().toISOString(),
  };
});

// ====================================================================
// FCM Foundation — ≥70% match-score push trigger point (send not yet
// implemented; see matchScorePushNotification.js)
// ====================================================================
const {
  onOpportunityMatchScoreUpdated,
} = require("./matchScorePushNotification");
exports.onOpportunityMatchScoreUpdated = onOpportunityMatchScoreUpdated;