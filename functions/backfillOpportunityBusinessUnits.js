const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");
const { buildBusinessUnitCatalog, matchBusinessUnitNames } = require("./businessUnitMatching");

function db() {
  return admin.firestore();
}

const GEMINI_MODEL = "gemini-2.5-flash";
const LOCATION = "us-central1";
const MAX_BATCH_SIZE = 50;

function genAiClient() {
  return new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT,
    location: LOCATION,
  });
}

function extractJson(text) {
  const match = text.match(/[[{][\s\S]*[\]}]/);
  if (!match) throw new Error(`No JSON found in model response: ${text.slice(0, 200)}`);
  return JSON.parse(match[0]);
}

/**
 * Builds the per-opportunity backfill prompt. The catalog is the ONLY
 * source of truth for what the model may return — it's told explicitly to
 * pick zero or more names from the list and never invent one, mirroring
 * `classifyOpportunity`'s "never invent an ID" rule (there IDs, here names,
 * since matching happens after the call — see `businessUnitMatching.js`).
 */
function buildBackfillPrompt({ title, client, description, category, tenderSourceCategory, tags, businessUnitNames }) {
  return `You are classifying a business tender/opportunity against a fixed list of
a company's Business Units. Choose ALL Business Units from the list below
that this opportunity belongs to — most opportunities genuinely span more
than one. For example, a US Embassy compound / ambassador residence / roof
replacement / diplomatic facility RFQ should get BOTH "Construction" AND
"Embassy & Diplomatic Facilities" (and "Facility Management" too when
ongoing building-services or fit-out work is involved). You MUST only
return names that appear verbatim in this list — never invent, rename, or
abbreviate a name that isn't listed exactly as written:

${businessUnitNames.map((n) => `- ${n}`).join("\n")}

Opportunity:
Title: ${title || "(none)"}
Client: ${client || "(none)"}
Category: ${category || "(none)"}
Tender source category: ${tenderSourceCategory || "(none)"}
Tags: ${(tags || []).join(", ") || "(none)"}
Description: ${description || "(none)"}

If the opportunity is ambiguous or doesn't clearly match any Business Unit
in the list, return an empty array — do not guess.

Return ONLY a JSON object of the form:
{ "businessUnitNames": string[] }
No commentary, no markdown fences, no explanation outside the JSON object.`;
}

async function classifyOneOpportunity(prompt) {
  const ai = genAiClient();
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
  });
  const text = response.text ?? "";
  if (!text.trim()) throw new Error("Empty response from model");
  const parsed = extractJson(text);
  const names = Array.isArray(parsed?.businessUnitNames) ? parsed.businessUnitNames : [];
  return names.filter((n) => typeof n === "string");
}

/**
 * Callable: backfillOpportunityBusinessUnits — { force?: boolean, limit?: number }
 *
 * Admin-gated bulk assignment of `Opportunity.businessUnitIds`, for the
 * long tail of opportunities predating Phase 2's BU tabs/filters that have
 * no BU assigned at all. Every candidate name the model returns is matched
 * against the REAL `businessUnits` catalog (see `businessUnitMatching.js`)
 * before being written — a name with no exact match is simply dropped
 * (logged, not silently discarded), never guessed and never used to create
 * a new Business Unit document. Idempotent by default: only opportunities
 * with an empty `businessUnitIds` are touched unless `force: true`.
 * Batched (`MAX_BATCH_SIZE` per call) to stay well under the callable
 * timeout — call it more than once (or raise `limit`, capped at
 * `MAX_BATCH_SIZE`) to work through a larger backlog.
 */
const backfillOpportunityBusinessUnits = onCall(
  { timeoutSeconds: 300 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can backfill business unit assignments",
      );
    }

    const force = request.data?.force === true;
    const requestedLimit = Number(request.data?.limit);
    const limit = Number.isFinite(requestedLimit) && requestedLimit > 0
      ? Math.min(requestedLimit, MAX_BATCH_SIZE)
      : MAX_BATCH_SIZE;

    const businessUnitsSnap = await db().collection("businessUnits").get();
    const businessUnits = businessUnitsSnap.docs.map((d) => ({
      id: d.id,
      name: d.data().name,
      slug: d.data().slug,
    }));
    if (businessUnits.length === 0) {
      return { processed: 0, updated: 0, skipped: 0, errors: 0 };
    }
    const catalog = buildBusinessUnitCatalog(businessUnits);
    const businessUnitNames = businessUnits.map((b) => b.name).filter(Boolean);

    const opportunitiesSnap = await db().collection("opportunities").limit(500).get();
    const candidates = opportunitiesSnap.docs.filter((d) => {
      if (force) return true;
      const ids = d.data().businessUnitIds;
      return !Array.isArray(ids) || ids.length === 0;
    });
    const batch = candidates.slice(0, limit);

    let updated = 0;
    let skipped = 0;
    let errors = 0;
    const now = admin.firestore.Timestamp.now();

    for (const doc of batch) {
      const opportunity = doc.data();
      try {
        const prompt = buildBackfillPrompt({
          title: opportunity.title,
          client: opportunity.client,
          description: opportunity.description,
          category: opportunity.opportunityType,
          tenderSourceCategory: opportunity.tenderSourceCategory,
          tags: opportunity.tags,
          businessUnitNames,
        });
        const names = await classifyOneOpportunity(prompt);
        const { ids, unmatched } = matchBusinessUnitNames(names, catalog);

        if (unmatched.length > 0) {
          logger.warn(
            `backfillOpportunityBusinessUnits: unmatched names for ${doc.id}: ${unmatched.join(", ")}`,
          );
        }

        if (ids.length === 0) {
          skipped += 1;
          continue;
        }

        await doc.ref.update({ businessUnitIds: ids, updatedAt: now });
        updated += 1;
      } catch (e) {
        logger.error(`backfillOpportunityBusinessUnits: failed for ${doc.id}`, e);
        errors += 1;
      }
    }

    return {
      processed: batch.length,
      updated,
      skipped: skipped + (candidates.length - batch.length),
      errors,
    };
  },
);

module.exports = { backfillOpportunityBusinessUnits };
