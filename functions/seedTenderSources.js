const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

function db() {
  return admin.firestore();
}

/**
 * The 30 organizations named in the Phase 3 / Phase 3.9 briefs. Every one
 * uses `discoveryMethod: "api"` in `connectorConfig.mode: "aiSearch"` —
 * the Gemini + Google Search grounded technique already proven working
 * since Milestone 3.8a (see ApiConnector._syncAiSearch). This is a
 * deliberate choice over hand-written scrapers: I have no verified
 * knowledge of any of these 30 sites' actual markup/API shape, and a
 * fabricated CSS selector or endpoint would look "production-ready" while
 * silently returning nothing. aiSearch needs no site-specific knowledge
 * and is genuinely functional today.
 *
 * `searchQuery` is tailored per source group toward JV ALMA CIS's real
 * business units (Construction, Agribusiness/Capacity Building/Community
 * Empowerment, Oil & Gas Services, Information Technology) rather than
 * left generic, so seeded sources return relevant candidates from day one
 * instead of noise.
 *
 * `seedKey` is a stable identifier (not shown in any UI) used only for
 * idempotency — re-running this function never creates duplicates, so
 * it's safe to call again after adding/removing entries from this list.
 */
const IT_AGRI_CONSTRUCTION_QUERY =
  "information technology systems, software development, digital infrastructure, agricultural technology, construction and civil works";

const DONOR_CONSTRUCTION_QUERY =
  "construction and civil works, infrastructure development, capacity building, community empowerment, information technology systems";

const DONOR_AGRI_DIGITAL_QUERY =
  "digital agriculture, agritech, capacity building, community empowerment programs, information technology systems for rural development";

const UN_AGRI_DIGITAL_QUERY =
  "digital agriculture and food systems technology, capacity building, information management systems for development programs";

const NGO_AGRI_DIGITAL_QUERY =
  "agricultural technology for smallholder farmers, digital tools for community development, capacity building software";

const EMBASSY_CONSTRUCTION_QUERY =
  "US embassy compound construction, ambassador residence renovation, diplomatic facilities design-build, roof replacement, fit-out Kenya East Africa";

const CAPACITY_IRRIGATION_QUERY =
  "irrigation scheme community capacity building, rural development agriculture infrastructure, water for production";

const INCUBATOR_DIGITAL_QUERY =
  "startup incubator digital solutions, innovation challenge agritech software, farm management app, CMMS facility management software, construction project management software, HR management system Kenya East Africa";

const AGRITECH_PRODUCTS_QUERY =
  "digital agriculture smallholder farmers, coffee traceability GIS farm mapping, EU deforestation regulation coffee, agriculture education digital platform schools";

const FACILITY_CMMS_QUERY =
  "CMMS facility management software, building maintenance management system";

const CONSTRUCTION_CM_QUERY =
  "construction project management software, site management digital tools";
const AGRITECH_SMALLHOLDER_QUERY =
  "digital agriculture smallholder farmers, farm records mobile app, pest disease diagnosis AI agriculture, yield cost tracking Kenya";

const COFFEE_TRACEABILITY_QUERY =
  "coffee traceability GIS farm mapping, EU deforestation regulation coffee export, coffee cooperative digital platform";

const HR_DIGITAL_QUERY =
  "HR management system SME, human resource digital platform workforce Kenya";

const ENERGY_PIPELINE_QUERY =
  "oil and gas tenders, pipeline construction and maintenance, petroleum infrastructure, energy facilities Kenya East Africa";

// Shared by every embassy/diplomatic-facilities source below, so a tender's
// wording (compound, ambassador residence, OBO, RPSO, roof, fit-out) stays
// consistent with `Embassy & Diplomatic Facilities`'s soft-match keywords
// in `opportunity_filters.dart` and its ALIASES entries in
// `businessUnitMatching.js` — same signals, three different layers.
const EMBASSY_DIPLOMATIC_EA_QUERY =
  "embassy compound construction Kenya, ambassador residence renovation, diplomatic facilities design-build, roof replacement, fit-out, OBO, RPSO East Africa";

const SEED_SOURCES = [
 // Kenya — national portal only (optional; not parastatals)
{
  seedKey: "ke-tenders",
  name: "Tenders Kenya (PPIP)",
  organization: "Government of Kenya — Public Procurement",
  category: "governmentAgency",
  country: "Kenya",
  website: "https://tenders.go.ke/tenders",
  searchQuery: `${DONOR_AGRI_DIGITAL_QUERY}, construction works, facility management, ICT systems`,
  tags: ["kenya", "national-portal"],
},
{
  seedKey: "ke-tendersoko",
  name: "Tendersoko",
  organization: "Tendersoko (private tender aggregator)",
  category: "governmentAgency",
  country: "Kenya",
  website: "https://www.tendersoko.com/tenders",
  searchQuery: `${DONOR_AGRI_DIGITAL_QUERY}, construction works, facility management, ICT systems`,
  tags: ["kenya", "aggregator"],
},
// LIMITATION: DevelopmentAid's most valuable listings (tender alerts
// matching a paid member's saved search criteria) are delivered by
// member-only email, not published on any page aiSearch's Google grounding
// can crawl — this source only ever sees whatever DevelopmentAid publishes
// on its public site, which is a small subset of what a paying member
// would receive. Mirroring the email alerts for real would need a
// dedicated EmailConnector (parsing inbound mail) or a manual/CSV import
// path — neither exists yet, and this seed deliberately does not fake one
// with a scraper against a member-only, likely-authenticated page.
// `website: null` (not the homepage) — confirmed there is no public tender
// listing page on developmentaid.org at all, so a URL here would just steer
// aiSearch toward a page with no tenders on it rather than help.
{
  seedKey: "dev-developmentaid",
  name: "DevelopmentAid",
  organization: "DevelopmentAid",
  category: "developmentPartner",
  country: null,
  website: null,
  searchQuery: `${DONOR_CONSTRUCTION_QUERY}, ${DONOR_AGRI_DIGITAL_QUERY}`,
  tags: ["development-partner", "aggregator"],
},
{
  seedKey: "ke-energy-pipeline",
  name: "Kenya Energy & Pipeline Tenders",
  organization: "Multi-source — oil, gas & pipeline procurement",
  category: "governmentAgency",
  country: "Kenya",
  website:null,
  searchQuery: ENERGY_PIPELINE_QUERY,
  tags: ["kenya", "oil-and-gas", "pipeline"],
},
// --- Embassy / diplomatic procurement (Embassy & Diplomatic Facilities BU) ---
{
  seedKey: "emb-us-nairobi-commercial",
  name: "US Embassy Nairobi — Commercial Opportunities",
  organization: "U.S. Embassy Nairobi",
  category: "governmentAgency",
  country: "Kenya",
  website: "https://ke.usembassy.gov/tag/commercial-opportunities/",
  searchQuery: EMBASSY_DIPLOMATIC_EA_QUERY,
  tags: ["embassy", "diplomatic", "united-states", "kenya"],
},
{
  seedKey: "emb-canada-buys",
  name: "CanadaBuys Tender Opportunities",
  organization: "Government of Canada / Canadian High Commission",
  category: "governmentAgency",
  country: null,
  website: "https://canadabuys.canada.ca/en/tender-opportunities",
  searchQuery: `${EMBASSY_DIPLOMATIC_EA_QUERY}, Canadian High Commission Nairobi`,
  tags: ["embassy", "diplomatic", "canada"],
},
{
  seedKey: "emb-eeas-tenders",
  name: "EU EEAS Tenders (Kenya)",
  organization: "European External Action Service",
  category: "developmentPartner",
  country: "Kenya",
  website: "https://www.eeas.europa.eu/eeas/tenders_en?fulltext=Kenya",
  searchQuery: EMBASSY_DIPLOMATIC_EA_QUERY,
  tags: ["embassy", "diplomatic", "eu"],
},
{
  seedKey: "emb-uk-find-a-tender",
  name: "UK Find a Tender",
  organization: "UK Government / British High Commission",
  category: "governmentAgency",
  country: null,
  website: "https://www.find-tender.service.gov.uk/Notice/",
  searchQuery: `${EMBASSY_DIPLOMATIC_EA_QUERY}, British High Commission Nairobi`,
  tags: ["embassy", "diplomatic", "united-kingdom"],
},
// Catch-all for embassy/diplomatic facility work whose issuing mission has
// no single stable public tender URL (many bilateral missions publish
// ad-hoc notices rather than a dedicated procurement portal) — aiSearch
// grounding covers these without inventing a fake per-country scraper.
{
  seedKey: "emb-diplomatic-facilities-ea-catchall",
  name: "Diplomatic Facilities — East Africa (multi-mission)",
  organization: "Multiple diplomatic missions — East Africa",
  category: "governmentAgency",
  country: null,
  website: null,
  searchQuery: EMBASSY_DIPLOMATIC_EA_QUERY,
  tags: ["embassy", "diplomatic", "east-africa", "multi-source"],
},
// Software / incubator oriented (aiSearch against those orgs’ procurement pages)
{
  seedKey: "incubator-digital-kenya",
  name: "Digital & Incubator Opportunities (Kenya / EA)",
  organization: "Multi-donor digital innovation",
  category: "developmentPartner",
  country: "Kenya",
  website: null,
  searchQuery: `${INCUBATOR_DIGITAL_QUERY}, ${AGRITECH_SMALLHOLDER_QUERY}, ${COFFEE_TRACEABILITY_QUERY}, ${CONSTRUCTION_CM_QUERY}, ${FACILITY_CMMS_QUERY}, ${HR_DIGITAL_QUERY}`,
  tags: ["incubator", "software", "digital"],
},
  // --- East Africa ---
  {
    seedKey: "ug-procurement",
    name: "Uganda Procurement Portal",
    organization: "Public Procurement and Disposal of Public Assets Authority",
    category: "governmentAgency",
    country: "Uganda",
    website: null,
    searchQuery: IT_AGRI_CONSTRUCTION_QUERY,
    tags: ["government", "east-africa"],
  },
  {
    seedKey: "tz-procurement",
    name: "Tanzania Procurement Portal",
    organization: "Public Procurement Regulatory Authority",
    category: "governmentAgency",
    country: "Tanzania",
    website: null,
    searchQuery: IT_AGRI_CONSTRUCTION_QUERY,
    tags: ["government", "east-africa"],
  },
  {
    seedKey: "rw-procurement",
    name: "Rwanda Procurement Portal",
    organization: "Rwanda Public Procurement Authority",
    category: "governmentAgency",
    country: "Rwanda",
    website: null,
    searchQuery: IT_AGRI_CONSTRUCTION_QUERY,
    tags: ["government", "east-africa"],
  },

  // Diplomatic / USG construction
{
  seedKey: "sam-gov",
  name: "SAM.gov",
  organization: "U.S. Government",
  category: "governmentAgency", // or usaGovernment if your enum allows
  country: null,
  website: "https://sam.gov/opportunities",
  searchQuery: EMBASSY_CONSTRUCTION_QUERY,
  tags: ["united-states", "embassy", "diplomatic"],
},

// AICS — critical for your Baringo / capacity story
// `website: null` — AICS HQ has no central public tender list; tenders are
// published separately per field office (Maputo, Jerusalem, etc.), so no
// single URL is authoritative here.
{
  seedKey: "dev-aics",
  name: "AICS",
  organization: "Italian Agency for Development Cooperation",
  category: "developmentPartner",
  country: null,
  website: null,
  searchQuery: `${CAPACITY_IRRIGATION_QUERY}, ${DONOR_AGRI_DIGITAL_QUERY}`,
  tags: ["development-partner", "italy", "capacity-building"],
},
  // --- Development Partners ---
  {
    seedKey: "dev-world-bank",
    name: "World Bank",
    organization: "World Bank Group",
    category: "developmentPartner",
    country: null,
    website: "https://projects.worldbank.org/en/projects-operations/procurement/notices",
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner"],
  },
  // `website: null` — AfDB has no single browsable public tender listing
  // page; opportunities go through field-office contact/vendor registration
  // rather than one central URL.
  {
    seedKey: "dev-afdb",
    name: "African Development Bank",
    organization: "African Development Bank Group",
    category: "developmentPartner",
    country: null,
    website: null,
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner", "africa"],
  },
  {
    seedKey: "dev-eu",
    name: "European Union",
    organization: "European Union",
    category: "developmentPartner",
    country: null,
    website: "https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/opportunities/calls-for-tenders",
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner"],
  },
  {
    seedKey: "dev-giz",
    name: "GIZ",
    organization: "Deutsche Gesellschaft für Internationale Zusammenarbeit",
    category: "developmentPartner",
    country: null,
    website: "https://www.giz.de/en/partner/contractor/tenders",
    searchQuery: `${DONOR_AGRI_DIGITAL_QUERY}, ${EMBASSY_DIPLOMATIC_EA_QUERY}`,
    tags: ["development-partner"],
  },
  // `website: null` — JICA has no single centralized public tender listing;
  // procurement info is scattered per-country/per-scheme rather than one
  // authoritative page.
  {
    seedKey: "dev-jica",
    name: "JICA",
    organization: "Japan International Cooperation Agency",
    category: "developmentPartner",
    country: null,
    website: null,
    searchQuery: `${DONOR_AGRI_DIGITAL_QUERY}, ${EMBASSY_DIPLOMATIC_EA_QUERY}`,
    tags: ["development-partner"],
  },
  {
    seedKey: "dev-fcdo",
    name: "FCDO",
    organization: "Foreign, Commonwealth & Development Office",
    category: "developmentPartner",
    country: null,
    website: "https://www.gov.uk/contracts-finder",
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner"],
  },
  {
    seedKey: "dev-afd",
    name: "AFD (Agence Française de Développement)",
    organization: "Agence Française de Développement",
    category: "developmentPartner",
    country: null,
    website: "https://tenders-afd.dgmarket.com/",
    searchQuery: DONOR_CONSTRUCTION_QUERY,
    tags: ["development-partner", "france"],
  },
  // `website: null` — SIDA doesn't maintain its own public tender listing;
  // procurement is advertised via the Swedish Kommers Annons e-procurement
  // platform, not a page on sida.se itself.
  {
    seedKey: "dev-sida",
    name: "SIDA",
    organization: "Swedish International Development Cooperation Agency",
    category: "developmentPartner",
    country: null,
    website: null,
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner", "sweden"],
  },
  {
    seedKey: "dev-ifad",
    name: "IFAD",
    organization: "International Fund for Agricultural Development",
    category: "developmentPartner",
    country: null,
    website: "https://www.ifad.org/en/project-procurement/opportunities",
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner", "agriculture"],
  },
  // `website: null` — Norad has no dedicated public tender listing page;
  // it publishes case-by-case via Norway's Doffin e-procurement portal and
  // through grant recipients' own sites, not norad.no itself.
  {
    seedKey: "dev-norad",
    name: "NORAD",
    organization: "Norwegian Agency for Development Cooperation",
    category: "developmentPartner",
    country: null,
    website: null,
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner", "norway"],
  },
  {
    seedKey: "dev-danida",
    name: "DANIDA",
    organization: "Danish International Development Agency",
    category: "developmentPartner",
    country: null,
    website: "https://um.dk/en/danida/procurement",
    searchQuery: DONOR_AGRI_DIGITAL_QUERY,
    tags: ["development-partner", "denmark"],
  },
  {
    seedKey: "ke-red-cross-tenders",
    name: "Kenya Red Cross Tenders",
    organization: "Kenya Red Cross Society",
    category: "ngo",
    country: "Kenya",
    website: "https://www.redcross.or.ke/tenders/",
    searchQuery: `${DONOR_CONSTRUCTION_QUERY}, ${CAPACITY_IRRIGATION_QUERY}`,
    tags: ["ngo", "kenya"],
  },

  // --- United Nations ---
  
   {
    seedKey: "un-undp",
    name: "UNDP",
    organization: "United Nations Development Programme",
    category: "unAgency",
    country: null,
    website: "https://procurement-notices.undp.org/",
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations"],
  },
  {
    seedKey: "un-unicef",
    name: "UNICEF",
    organization: "United Nations Children's Fund",
    category: "unAgency",
    country: null,
    website: "https://www.unicef.org/supply/tender-calendars",
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations"],
  },
  // `website: null` — FAO has no single global public tender listing page;
  // procurement routes through UNGM (a shared UN portal, not fao.org).
  {
    seedKey: "un-fao",
    name: "FAO",
    organization: "Food and Agriculture Organization",
    category: "unAgency",
    country: null,
    website: null,
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations", "agriculture"],
  },
  {
    seedKey: "un-wfp",
    name: "WFP",
    organization: "World Food Programme",
    category: "unAgency",
    country: null,
    website: "https://www.wfp.org/procurement",
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations", "agriculture"],
  },
  // `website: null` — UNOPS doesn't publish tenders directly on unops.org;
  // they're only visible through UNGM after registration.
  {
    seedKey: "un-unops",
    name: "UNOPS",
    organization: "United Nations Office for Project Services",
    category: "unAgency",
    country: null,
    website: null,
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations"],
  },
  // `website: null` — no dedicated central tenders page on unep.org;
  // procurement is routed through UNGM instead.
  {
    seedKey: "un-unep",
    name: "UNEP",
    organization: "United Nations Environment Programme",
    category: "unAgency",
    country: null,
    website: null,
    searchQuery: UN_AGRI_DIGITAL_QUERY,
    tags: ["united-nations", "environment"],
  },

  // --- NGOs ---
  {
    seedKey: "ngo-world-vision",
    name: "World Vision",
    organization: "World Vision International",
    category: "ngo",
    country: null,
    website: "https://www.wvi.org/suppliers/tenders",
    searchQuery: NGO_AGRI_DIGITAL_QUERY,
    tags: ["ngo"],
  },
  {
    seedKey: "ngo-care",
    name: "CARE",
    organization: "CARE International",
    category: "ngo",
    country: null,
    website: "https://www.care.org/about-us/contact-us/request-for-proposals/",
    searchQuery: NGO_AGRI_DIGITAL_QUERY,
    tags: ["ngo"],
  },
  {
    seedKey: "ngo-mercy-corps",
    name: "Mercy Corps",
    organization: "Mercy Corps",
    category: "ngo",
    country: null,
    website: "https://www.mercycorps.org/tenders",
    searchQuery: NGO_AGRI_DIGITAL_QUERY,
    tags: ["ngo"],
  },
  {
    seedKey: "ngo-save-the-children",
    name: "Save the Children",
    organization: "Save the Children International",
    category: "ngo",
    country: null,
    website: "https://www.savethechildren.net/tenders",
    searchQuery: NGO_AGRI_DIGITAL_QUERY,
    tags: ["ngo"],
  },
  {
    seedKey: "ngo-snv",
    name: "SNV",
    organization: "SNV Netherlands Development Organisation",
    category: "ngo",
    country: null,
    website: "https://www.snv.org/tenders",
    searchQuery: NGO_AGRI_DIGITAL_QUERY,
    tags: ["ngo", "agriculture"],
  },
];

/**
 * Callable: seedProductionTenderSources — creates any of the 30 SEED_SOURCES
 * entries that don't already exist (matched by `seedKey`, idempotent — safe
 * to call more than once). Every created source defaults to `enabled: true`
 * with a conservative daily `syncFrequencyMinutes` (aiSearch makes a real
 * Gemini + Google Search call, so this deliberately doesn't default to an
 * hourly cadence across 30 sources at once).
 *
 * Admin-gated: writes here go through the Admin SDK, which bypasses
 * firestore.rules' `isAdmin()` check on `tenderSources` — so this function
 * does that check itself instead, mirroring the same rule.
 */
const seedProductionTenderSources = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can seed tender sources",
      );
    }

    // Fetching the whole collection and filtering in-memory rather than a
    // `where('seedKey', 'in', [...])` query — Firestore caps 'in' at 30
    // values, which happens to match today's count but would silently
    // break dedup the moment a 31st source is added to SEED_SOURCES.
    // tenderSources is small at this stage, so this is cheap.
    const existingSnap = await db().collection("tenderSources").get();
    const existingKeys = new Set(
      existingSnap.docs
        .map((d) => d.data().seedKey)
        .filter((k) => typeof k === "string"),
    );

    let created = 0;
    const now = admin.firestore.Timestamp.now();
    const batch = db().batch();

    for (const seed of SEED_SOURCES) {
      if (existingKeys.has(seed.seedKey)) continue;

      const ref = db().collection("tenderSources").doc();
      batch.set(ref, {
        seedKey: seed.seedKey,
        name: seed.name,
        organization: seed.organization,
        category: seed.category,
        discoveryMethod: "api",
        country: seed.country,
        website: seed.website,
        searchQuery: seed.searchQuery,
        connectorConfig: { mode: "aiSearch" },
        authConfig: {},
        status: "active",
        enabled: true,
        syncFrequencyMinutes: 1440,
        lastSyncAt: null,
        lastSuccessAt: null,
        lastFailureAt: null,
        lastErrorMessage: null,
        healthScore: 100,
        aiQualityScore: null,
        historicalWinRatePercent: null,
        opportunitiesImported: 0,
        opportunitiesPursued: 0,
        wins: 0,
        losses: 0,
        tags: seed.tags,
        createdAt: now,
        updatedAt: now,
      });
      created += 1;
    }

    if (created > 0) await batch.commit();

    const skipped = SEED_SOURCES.length - created;
    logger.info(
      `seedProductionTenderSources: created ${created}, skipped ${skipped} (already existed)`,
    );
    return { created, skipped, total: SEED_SOURCES.length };
  },
);

module.exports = { seedProductionTenderSources, SEED_SOURCES };

// ============================================================================
// ADD TO functions/index.js, alongside the other Tender Source exports:
//
//   const { seedProductionTenderSources } = require("./seedTenderSources");
//   exports.seedProductionTenderSources = seedProductionTenderSources;
// ============================================================================