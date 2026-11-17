const { humanizeIds, humanizeDeep } = require("./lib/humanizeIds");

/**
 * One-off cleanup for AI-written text stored before IDs were replaced at
 * the source (see humanizeAiJson in index.js): rewrites raw document IDs
 * in stored AI text into the names they refer to. Only the AI text fields
 * listed below are touched, a document is only written when its text
 * actually changes, and `...Id(s)` reference fields are never modified.
 */

/** Collections whose names an AI prompt may have listed, and their name field. */
const NAME_SOURCES = [
  { collection: "opportunities", field: "title" },
  { collection: "proposals", field: "title" },
  { collection: "businessUnits", field: "name" },
  { collection: "products", field: "name" },
  { collection: "services", field: "name" },
  { collection: "capabilities", field: "name" },
  { collection: "technologies", field: "name" },
  { collection: "industries", field: "name" },
  { collection: "experiences", field: "title" },
  { collection: "knowledgeBase", field: "title" },
];

/** AI-written fields per collection. */
const AI_TEXT_FIELDS = {
  recommendations: ["title", "reasoning"],
  opportunities: [
    "classificationSummary",
    "fitReasoning",
    "strategicRecommendation",
    "strengths",
    "gaps",
    "risks",
    "nextActions",
    "executiveSummary",
    "strategicStrengths",
    "strategicWeaknesses",
    "strategicRisks",
    "mitigationStrategies",
    "competitiveAdvantages",
    "missingRequirements",
    "nextRecommendedActions",
    "proposalPositioningStrategy",
  ],
  proposals: [
    "submissionReviewMissingEvidence",
    "submissionReviewWeakSections",
    "submissionReviewStrongSections",
    "submissionReviewComplianceConcerns",
    "submissionReviewRecommendedImprovements",
  ],
  proposalSections: ["content"],
};

async function loadNames(db) {
  const names = new Map();
  const snaps = await Promise.all(NAME_SOURCES.map((s) => db.collection(s.collection).get()));
  snaps.forEach((snap, i) => {
    const field = NAME_SOURCES[i].field;
    for (const d of snap.docs) {
      const name = d.data()[field];
      if (typeof name === "string" && name.trim()) names.set(d.id, name.trim());
    }
  });
  return names;
}

/** The changed fields of [data] after cleaning [fields]; {} when nothing changes. */
function cleanedFields(data, fields, names) {
  const update = {};
  for (const field of fields) {
    const before = data[field];
    if (before == null) continue;
    const after = typeof before === "string" ? humanizeIds(before, names) : humanizeDeep(before, names);
    if (JSON.stringify(after) !== JSON.stringify(before)) update[field] = after;
  }
  return update;
}

/** Runs the cleanup; returns `{ [collection]: docsUpdated, executiveSummary: 0|1 }`. */
async function cleanStoredAiText(db) {
  const names = await loadNames(db);
  const result = {};

  for (const [collection, fields] of Object.entries(AI_TEXT_FIELDS)) {
    const snap = await db.collection(collection).get();
    let updated = 0;
    let batch = db.batch();
    let pending = 0;
    for (const d of snap.docs) {
      const update = cleanedFields(d.data(), fields, names);
      if (Object.keys(update).length === 0) continue;
      batch.update(d.ref, update);
      updated += 1;
      pending += 1;
      if (pending === 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    result[collection] = updated;
  }

  const summaryRef = db.collection("analytics").doc("executiveSummary");
  const summarySnap = await summaryRef.get();
  result.executiveSummary = 0;
  if (summarySnap.exists) {
    const update = cleanedFields(summarySnap.data(), ["narrative", "insights"], names);
    if (Object.keys(update).length > 0) {
      await summaryRef.update(update);
      result.executiveSummary = 1;
    }
  }
  return result;
}

module.exports = { cleanStoredAiText, cleanedFields, AI_TEXT_FIELDS };
