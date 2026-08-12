const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

function db() {
  return admin.firestore();
}

/**
 * A minimal, honest starting spine for JV ALMA CIS's Company Intelligence
 * graph — not a full taxonomy, just enough real entities that extraction
 * (`extractProjectDocumentKnowledge`) and classification have something to
 * actually match against instead of always returning `[]`. Extraction never
 * invents Business Units/Capabilities/Industries/Services itself (see that
 * function's prompt) — these have to exist first, by hand, which is what
 * this seed is for.
 *
 * `seedKey` is a stable identifier (not shown in any UI) used only for
 * idempotency, same convention as `seedTenderSources.js`'s `SEED_SOURCES` —
 * re-running this function never creates duplicates.
 *
 * Deliberately no Products/Technologies here — the brief is explicit that
 * only 2-3 should be added if the data model *requires* non-empty graph
 * sections to function, and it doesn't (buildKnowledgeGraph renders "(none
 * recorded yet)" for an empty collection and extraction just returns []
 * for that field, same as any other unmatched category). Adding filler
 * Products/Technologies here would mean inventing entities on JV ALMA
 * CIS's behalf, which is exactly what this task forbids.
 */
const SEED_BUSINESS_UNITS = [
  {
    seedKey: "bu-construction",
    name: "Construction",
    slug: "construction",
    summary: "General contracting and construction delivery.",
  },
  {
    seedKey: "bu-embassy-diplomatic",
    name: "Embassy & Diplomatic Facilities",
    slug: "embassy-diplomatic-facilities",
    summary:
      "Construction, renovation, and facilities work for embassies and diplomatic compounds.",
  },
  {
    seedKey: "bu-development-programmes",
    name: "Development Programmes",
    slug: "development-programmes",
    summary:
      "Agribusiness, capacity building, and community empowerment programme delivery.",
  },
];

const SEED_CAPABILITIES = [
  {
    seedKey: "cap-roof-replacement-waterproofing",
    name: "Roof Replacement & Waterproofing",
    slug: "roof-replacement-waterproofing",
    summary: "Roof replacement, repair, and waterproofing works.",
  },
  {
    seedKey: "cap-interior-renovation-fitout",
    name: "Interior Renovation & Fit-Out",
    slug: "interior-renovation-fit-out",
    summary: "Interior renovation, refurbishment, and fit-out works.",
  },
  {
    seedKey: "cap-design-build-construction",
    name: "Design-Build Construction",
    slug: "design-build-construction",
    summary: "Combined design and construction delivery under one contract.",
  },
  {
    seedKey: "cap-mep-building-services",
    name: "MEP / Building Services Coordination",
    slug: "mep-building-services-coordination",
    summary:
      "Mechanical, electrical, and plumbing building services coordination.",
  },
];

const SEED_INDUSTRIES = [
  {
    seedKey: "ind-diplomatic-embassy-compounds",
    name: "Diplomatic & Embassy Compounds",
    sector: "Government / Diplomatic",
  },
  {
    seedKey: "ind-residential-compounds",
    name: "Residential Compounds",
    sector: "Residential",
  },
  {
    seedKey: "ind-rural-development-agribusiness",
    name: "Rural Development & Agribusiness",
    sector: "Agriculture / Development",
  },
];

const SEED_SERVICES = [
  {
    seedKey: "svc-general-contracting",
    name: "General Contracting",
    slug: "general-contracting",
    summary: "End-to-end general contracting services.",
  },
  {
    seedKey: "svc-project-management",
    name: "Project Management",
    slug: "project-management",
    summary: "Project management and delivery oversight services.",
  },
];

/**
 * Fetches a collection's existing `seedKey`s once — mirrors
 * `seedProductionTenderSources`'s dedup approach (fetch-all-and-filter-in-
 * memory rather than an `in` query, since these collections are small and
 * an `in` query caps at 30 values anyway).
 */
async function existingSeedKeys(collection) {
  const snap = await db().collection(collection).get();
  return new Set(
    snap.docs.map((d) => d.data().seedKey).filter((k) => typeof k === "string"),
  );
}

function seedOneCollection(batch, collection, seeds, existingKeys, buildDoc) {
  let created = 0;
  const now = admin.firestore.Timestamp.now();
  for (const seed of seeds) {
    if (existingKeys.has(seed.seedKey)) continue;
    const ref = db().collection(collection).doc();
    batch.set(ref, buildDoc(seed, now));
    created += 1;
  }
  return created;
}

/**
 * Callable: seedCompanyIntelligenceSpine — creates any of the seed
 * Business Units/Capabilities/Industries/Services above that don't already
 * exist (matched by `seedKey`, idempotent — safe to call more than once).
 * Admin-gated the same way as `seedProductionTenderSources`: writes here go
 * through the Admin SDK, which bypasses firestore.rules, so this function
 * checks the caller's `users/{uid}.role` itself.
 */
const seedCompanyIntelligenceSpine = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can seed the Company Intelligence spine",
      );
    }

    const [buKeys, capKeys, indKeys, svcKeys] = await Promise.all([
      existingSeedKeys("businessUnits"),
      existingSeedKeys("capabilities"),
      existingSeedKeys("industries"),
      existingSeedKeys("services"),
    ]);

    const batch = db().batch();

    const businessUnitsCreated = seedOneCollection(
      batch,
      "businessUnits",
      SEED_BUSINESS_UNITS,
      buKeys,
      (seed, now) => ({
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
      }),
    );

    const capabilitiesCreated = seedOneCollection(
      batch,
      "capabilities",
      SEED_CAPABILITIES,
      capKeys,
      (seed, now) => ({
        seedKey: seed.seedKey,
        name: seed.name,
        slug: seed.slug,
        summary: seed.summary,
        description: "",
        keywords: [],
        tags: [],
        status: "active",
        businessRelevance: null,
        productIds: [],
        serviceIds: [],
        aiExpertiseSummary: null,
        aiExpertiseHighlights: [],
        aiExpertiseSummaryGeneratedAt: null,
        createdAt: now,
        updatedAt: now,
      }),
    );

    const industriesCreated = seedOneCollection(
      batch,
      "industries",
      SEED_INDUSTRIES,
      indKeys,
      (seed, now) => ({
        seedKey: seed.seedKey,
        name: seed.name,
        description: "",
        sector: seed.sector,
        tags: [],
        businessUnitIds: [],
        productIds: [],
        capabilityIds: [],
        technologyIds: [],
        experienceIds: [],
        aiExpertiseSummary: null,
        aiExpertiseHighlights: [],
        aiExpertiseSummaryGeneratedAt: null,
        status: "active",
        createdAt: now,
        updatedAt: now,
      }),
    );

    const servicesCreated = seedOneCollection(
      batch,
      "services",
      SEED_SERVICES,
      svcKeys,
      (seed, now) => ({
        seedKey: seed.seedKey,
        name: seed.name,
        slug: seed.slug,
        summary: seed.summary,
        description: "",
        businessUnitIds: [],
        status: "active",
        capabilityIds: [],
        industryIds: [],
        pastProjectIds: [],
        aiExpertiseSummary: null,
        aiExpertiseHighlights: [],
        aiExpertiseSummaryGeneratedAt: null,
        createdAt: now,
        updatedAt: now,
      }),
    );

    const totalCreated =
      businessUnitsCreated + capabilitiesCreated + industriesCreated + servicesCreated;
    if (totalCreated > 0) await batch.commit();

    const result = {
      businessUnits: {
        created: businessUnitsCreated,
        skipped: SEED_BUSINESS_UNITS.length - businessUnitsCreated,
      },
      capabilities: {
        created: capabilitiesCreated,
        skipped: SEED_CAPABILITIES.length - capabilitiesCreated,
      },
      industries: {
        created: industriesCreated,
        skipped: SEED_INDUSTRIES.length - industriesCreated,
      },
      services: {
        created: servicesCreated,
        skipped: SEED_SERVICES.length - servicesCreated,
      },
      totalCreated,
      totalSkipped:
        SEED_BUSINESS_UNITS.length +
        SEED_CAPABILITIES.length +
        SEED_INDUSTRIES.length +
        SEED_SERVICES.length -
        totalCreated,
    };

    logger.info(
      `seedCompanyIntelligenceSpine: created ${totalCreated}, skipped ${result.totalSkipped}`,
    );
    return result;
  },
);

module.exports = { seedCompanyIntelligenceSpine };
