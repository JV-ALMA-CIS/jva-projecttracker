const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { normalizeName } = require("./businessUnitMatching");

function db() {
  return admin.firestore();
}

/**
 * The canonical, stable JV ALMA CIS Business Unit list this app's
 * classification/backfill/matching pipeline is built around — see
 * `businessUnitMatching.js`'s `ALIASES` map, which resolves abbreviations
 * ("FM", "IT", "agri", "HR") to these exact names. Deliberately a separate,
 * narrower seed from `seedCompanyIntelligenceSpine.js` (which seeds a
 * different, broader BU shape — "Embassy & Diplomatic Facilities",
 * "Development Programmes" — for a different purpose): that seed is
 * untouched here. `seedKey` follows the same stable-identifier convention
 * as every other seed list in this app (`seedTenderSources.js`,
 * `seedCompanyIntelligenceSpine.js`) — re-running this is always safe.
 */
const SEED_BUSINESS_UNITS = [
  {
    seedKey: "bu-construction",
    name: "Construction",
    slug: "construction",
    summary: "General contracting and construction delivery.",
  },
  {
    seedKey: "bu-facility-management",
    name: "Facility Management",
    slug: "facility-management",
    summary: "Facility operations, maintenance, and management services.",
  },
  {
    seedKey: "bu-agribusiness",
    name: "Agribusiness",
    slug: "agribusiness",
    summary: "Agriculture, agritech, and rural development programme delivery.",
  },
  {
    seedKey: "bu-information-technology",
    name: "Information Technology",
    slug: "information-technology",
    summary: "Software, digital systems, and IT infrastructure services.",
  },
  {
    seedKey: "bu-human-resources",
    name: "Human Resources",
    slug: "human-resources",
    summary: "Human resources and workforce management services.",
  },
];

/**
 * Callable: seedCompanyBusinessUnits — creates any of the canonical
 * Business Units above that don't already exist, matched by BOTH
 * `seedKey` AND case-insensitive `name` (unlike `seedCompanyIntelligenceSpine`'s
 * seedKey-only dedup) — this seed is explicitly meant to run alongside an
 * organically-grown `businessUnits` collection (e.g. one already seeded by
 * `seedCompanyIntelligenceSpine` or created by hand from the Company
 * Intelligence screens), so a Business Unit that already exists under a
 * different seedKey but the same name is still recognized and skipped
 * rather than duplicated. Idempotent — safe to call more than once.
 * Admin-gated the same way as `seedProductionTenderSources`/
 * `seedCompanyIntelligenceSpine`: writes here go through the Admin SDK,
 * which bypasses firestore.rules, so this function checks the caller's
 * `users/{uid}.role` itself.
 */
const seedCompanyBusinessUnits = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can seed business units",
      );
    }

    const existingSnap = await db().collection("businessUnits").get();
    const existingSeedKeys = new Set(
      existingSnap.docs
        .map((d) => d.data().seedKey)
        .filter((k) => typeof k === "string"),
    );
    const existingNames = new Set(
      existingSnap.docs.map((d) => normalizeName(d.data().name)),
    );

    const now = admin.firestore.Timestamp.now();
    const batch = db().batch();
    let created = 0;

    for (const seed of SEED_BUSINESS_UNITS) {
      if (existingSeedKeys.has(seed.seedKey)) continue;
      if (existingNames.has(normalizeName(seed.name))) continue;

      const ref = db().collection("businessUnits").doc();
      batch.set(ref, {
        seedKey: seed.seedKey,
        name: seed.name,
        slug: seed.slug,
        summary: seed.summary,
        description: "",
        status: "active",
        productIds: [],
        serviceIds: [],
        capabilityIds: [],
        industryIds: [],
        technologyIds: [],
        pastProjectIds: [],
        aiExpertiseSummary: null,
        aiExpertiseHighlights: [],
        aiExpertiseSummaryGeneratedAt: null,
        createdAt: now,
        updatedAt: now,
      });
      created += 1;
    }

    if (created > 0) await batch.commit();

    const skipped = SEED_BUSINESS_UNITS.length - created;
    logger.info(
      `seedCompanyBusinessUnits: created ${created}, skipped ${skipped} (already existed)`,
    );
    return { created, skipped, total: SEED_BUSINESS_UNITS.length };
  },
);

module.exports = { seedCompanyBusinessUnits };
