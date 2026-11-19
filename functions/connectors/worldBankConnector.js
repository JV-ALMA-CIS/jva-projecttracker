const { readableTitle } = require("./ppipConnector");
const { importScoredTenders, findExistingMatch } = require("../lib/feedImport");

/**
 * World Bank procurement notices (official public API, free, no key) for
 * Kenya and East Africa: invitations for bids and expressions of interest
 * on World Bank-financed projects — civil works, goods, IT systems,
 * consulting. First-hand, published the same day as on the Bank's site;
 * the same notices aggregators like DevelopmentAid resell.
 *
 * Many of these are procured by a Kenyan public body (ICT Authority,
 * KeNHA, counties, KALRO), so when the same tender arrives from the Kenyan
 * government portal (PPIP) without mentioning the donor, the buyer policy
 * archives it as "public buyer". This connector fixes that blind spot: a
 * World Bank notice that matches an archived tender RESTORES it (with the
 * funding recorded) instead of adding a duplicate.
 *
 * Privacy: the notices carry procurement officers' names, emails and
 * phone numbers — only non-personal fields are ever read or stored.
 *
 * Daily: fetch open notices, skip ones already scored (memory collection),
 * AI-score the rest in batches, save those scoring >= MIN_FIT_SCORE. The
 * very first run (empty memory) is quiet — no alert per tender.
 */

const API = "https://search.worldbank.org/api/v2/procnotices";
const COUNTRIES = ["Kenya", "Uganda", "Tanzania", "Rwanda", "Burundi"];
const NOTICE_TYPES = ["Invitation for Bids", "Request for Expression of Interest"];
/** Individual consultant hires are jobs for a person, not company work. */
const SKIPPED_METHODS = new Set(["INDV"]);
const SCORED_COLLECTION = "worldBankScoredNotices";
const MIN_FIT_SCORE = 50;
const SCORING_BATCH_SIZE = 60;
const NOTICE_URL = "https://projects.worldbank.org/en/projects-operations/procurement-detail/";

const GROUP_LABELS = {
  CW: "Civil works",
  GO: "Goods",
  NC: "Non-consulting services",
  CS: "Consulting services",
};

/** The submission deadline as a Date (local East Africa time, UTC+3), or null. */
function parseDeadline(dateValue, timeValue) {
  const day = String(dateValue || "").slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  const time = /^\d{1,2}:\d{2}$/.test(String(timeValue || "").trim())
    ? String(timeValue).trim().padStart(5, "0")
    : "23:59";
  const d = new Date(`${day}T${time}:00+03:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Pure: the non-personal fields of one API notice, or null if it isn't a
 * usable open tender (no title, past deadline, individual-consultant hire).
 */
function toNotice(n, now = new Date()) {
  if (!n || !n.id || !n.bid_description) return null;
  if (SKIPPED_METHODS.has(String(n.procurement_method_code || "").toUpperCase())) return null;
  const deadline = parseDeadline(n.submission_deadline_date, n.submission_deadline_time);
  if (!deadline || deadline <= now) return null;
  return {
    id: String(n.id),
    title: readableTitle(String(n.bid_description).replace(/\s+/g, " ").trim()),
    noticeType: n.notice_type || "",
    country: n.project_ctry_name || "",
    projectId: n.project_id || "",
    projectName: n.project_name || "",
    reference: n.bid_reference_no || "",
    group: GROUP_LABELS[n.procurement_group] || n.procurement_group || "",
    method: n.procurement_method_name || "",
    buyer: n.contact_organization || "",
    deadline,
    sourceUrl: `${NOTICE_URL}${encodeURIComponent(String(n.id))}`,
  };
}

/** Every open notice for the watched countries and notice types. */
async function fetchOpenNotices({ fetchImpl = fetch, now = new Date(), logger = console } = {}) {
  const byId = new Map();
  for (const country of COUNTRIES) {
    for (const type of NOTICE_TYPES) {
      const url =
        `${API}?format=json&rows=100&srt=submission_date&order=desc` +
        `&project_ctry_name=${encodeURIComponent(country)}&notice_type_exact=${encodeURIComponent(type)}`;
      try {
        const res = await fetchImpl(url, { headers: { Accept: "application/json" } });
        if (!res.ok) {
          logger.warn(`worldBank: ${country} / ${type} → HTTP ${res.status}`);
          continue;
        }
        const body = await res.json();
        for (const raw of Object.values(body?.procnotices || {})) {
          const notice = toNotice(raw, now);
          if (notice) byId.set(notice.id, notice);
        }
      } catch (e) {
        logger.warn(`worldBank: ${country} / ${type} failed: ${e.message}`);
      }
    }
  }
  return [...byId.values()];
}

function buildScoringPrompt(profile, notices) {
  const lines = notices
    .map((t, i) => `${i} | ${t.title} | ${t.group || "?"} | ${t.buyer || "?"}, ${t.country} | project: ${t.projectName}`)
    .join("\n");
  return `You are a bid advisor for JV ALMA CIS, a Kenyan company (Italian parent
company) with business units in construction, facility management, embassy &
diplomatic facilities, agribusiness, information technology, oil & gas
inspection services and human resources, which also builds its own software
platforms. It has NO experience in solar / photovoltaic / energy generation.
Company profile:

${profile}

Below are open World Bank-financed tenders in East Africa (index | title |
procurement type | buyer, country | project). For EACH give a fit score
(0-100) for how well it matches what the company actually does. Be strict:
supply of goods it doesn't deal in (vehicles, drugs, fuel, food, medical
equipment), solar / energy generation, and large highways beyond a mid-size
contractor should score low; building works, facility management, ICT
systems and software, GIS / data, and agribusiness work it can deliver should
score higher.
Score noticeably higher (and say so in the reason) when a tender closely resembles
one of the company's past projects listed in the profile above (e.g. embassy or
diplomatic-residence renovation, roofing, building works for foreign missions, an
AICS-type agribusiness programme) — proven track record wins bids.
Give a one-sentence reason.

Tenders:
${lines}

Return ONLY a JSON array with one object per tender:
[{"index": number, "fitScorePercent": number, "fitReasoning": string}]
No commentary, no markdown fences.`;
}

function descriptionFor(t) {
  return [
    `World Bank-financed: ${t.projectName}${t.projectId ? ` (${t.projectId})` : ""}.`,
    [t.noticeType, t.group, t.method].filter(Boolean).join(" · ") + ".",
    t.buyer ? `Procuring entity: ${t.buyer}, ${t.country}.` : `Country: ${t.country}.`,
  ].join(" ");
}

const SOURCE = {
  key: "worldBank",
  label: "World Bank-financed project",
  memoryCollection: SCORED_COLLECTION,
  tags: ["world-bank", "donor-funded"],
  fundedBy: "World Bank",
  tenderSourceCategory: "developmentPartner",
  externalIdPrefix: "wb",
  descriptionFor,
  scoringPrompt: buildScoringPrompt,
  restoredReason: (t) => `World Bank-financed (${t.projectName}) — restored from public-buyer archive`,
};

/**
 * Full run (see lib/feedImport.js for the shared score / save / restore
 * logic). Dependencies injected for testing. Returns counts
 * {fetched, alreadyScored, scored, created, restored, quiet}.
 */
async function runWorldBankDiscovery({ db, admin, buildProfile, scoreBatch, fetchImpl = fetch, now = new Date(), logger = console, quiet }) {
  const items = await fetchOpenNotices({ fetchImpl, now, logger });
  return importScoredTenders({
    db,
    admin,
    items,
    source: SOURCE,
    buildProfile,
    scoreBatch,
    now,
    logger,
    quiet,
    minScore: MIN_FIT_SCORE,
    batchSize: SCORING_BATCH_SIZE,
  });
}

module.exports = {
  COUNTRIES,
  NOTICE_TYPES,
  MIN_FIT_SCORE,
  parseDeadline,
  toNotice,
  fetchOpenNotices,
  buildScoringPrompt,
  findExistingMatch,
  runWorldBankDiscovery,
};
