const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");

const GEMINI_MODEL = "gemini-2.5-flash";
const LOCATION = "us-central1";

/**
 * NOTE ON DUPLICATION: `genAiClient`/`buildCompanyProfile`/`extractJson`
 * already exist as private top-level functions in functions/index.js
 * (lines 1-45ish). They are duplicated here rather than imported, because
 * index.js doesn't currently export them and this milestone intentionally
 * avoids touching index.js's existing, already-tested top section.
 * Recommended follow-up (flagged in the milestone report, not done here):
 * move the index.js copies to require() from this file instead, so there's
 * one implementation. Until then, keep both copies in sync if you change
 * the Gemini call shape.
 */

function db() {
  return admin.firestore();
}

function genAiClient() {
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
    db().collection("projects").limit(100).get(),
    db().collection("applications").limit(100).get(),
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

module.exports = { GEMINI_MODEL, genAiClient, extractJson, buildCompanyProfile };