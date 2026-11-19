const { readableTitle } = require("./ppipConnector");
const { fetchPageImpl } = require("../lib/fetchPage");
const { importScoredTenders } = require("../lib/feedImport");

/**
 * UNDP procurement notices (procurement-notices.undp.org — UNDP's own
 * public list, no login) for Kenya and East Africa: RFQs, RFPs and ITBs
 * from UNDP country offices. The page lists every country office in one
 * regular table; rows are parsed directly (no AI to read the page) and
 * only East African offices kept. Individual-consultant (IC) hires are
 * jobs for a person, not company work, and are skipped.
 *
 * Scoring / saving / quiet first run: lib/feedImport.js.
 */

const LIST_URL = "https://procurement-notices.undp.org/search.cfm";
const BASE = "https://procurement-notices.undp.org/";
/** UNDP office codes (e.g. "UNDP-KEN/KENYA") for the five allowed countries. */
const OFFICES = { KEN: "Kenya", UGA: "Uganda", TZA: "Tanzania", RWA: "Rwanda", BDI: "Burundi" };
const SCORED_COLLECTION = "undpScoredNotices";
const MIN_FIT_SCORE = 50;
const BROWSER_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

const MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 };

/**
 * "23-Nov-26 05:40 AM (New York time)" → Date. New York is taken as UTC−5
 * (EST); during US summer time that's an hour off, harmless for a deadline
 * shown in days.
 */
function parseUndpDeadline(text) {
  const m = String(text || "").match(/(\d{1,2})-([A-Za-z]{3})-(\d{2,4})(?:\s+(\d{1,2}):(\d{2})\s*(AM|PM))?/);
  if (!m) return null;
  const month = MONTHS[m[2].toLowerCase()];
  if (month === undefined) return null;
  const year = m[3].length === 2 ? 2000 + Number(m[3]) : Number(m[3]);
  let hour = m[4] ? Number(m[4]) % 12 : 23;
  if (m[6] && m[6].toUpperCase() === "PM") hour += 12;
  const minute = m[5] ? Number(m[5]) : 59;
  return new Date(Date.UTC(year, month, Number(m[1]), hour + 5, minute));
}

const clean = (s) =>
  String(s || "")
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#39;|&rsquo;/g, "'")
    .replace(/&[a-z#0-9]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();

/**
 * Pure: the East African, still-open, non-IC rows of the notices table.
 * Each row is an <a href="view_...cfm?..." class="... vacanciesTable__row">
 * whose cells are labelled Title / Ref No / UNDP Office/Country / Process /
 * Deadline / Posted.
 */
function parseNotices(html, now = new Date()) {
  const notices = [];
  const rowRe = /<a\s+href="(view_[a-z_]+\.cfm\?[^"]+)"[^>]*vacanciesTable__row[^>]*>([\s\S]*?)<\/a>/gi;
  for (const m of String(html).matchAll(rowRe)) {
    const cells = {};
    const cellRe = /vacanciesTable__cell__label">\s*([^<]+?)\s*<\/div>\s*<span>([\s\S]*?)<\/span>/gi;
    for (const c of m[2].matchAll(cellRe)) cells[c[1].trim().toLowerCase()] = clean(c[2]);
    const office = cells["undp office/country"] || "";
    const code = (office.match(/-([A-Z]{3})\b/) || [])[1];
    if (!code || !OFFICES[code]) continue;
    const process = cells.process || "";
    if (/^IC\b|individual (contractor|consultant)/i.test(process)) continue;
    const title = cells.title || "";
    if (!title) continue;
    const deadline = parseUndpDeadline(cells.deadline);
    if (!deadline || deadline <= now) continue;
    const href = m[1].replace(/&amp;/g, "&");
    const id = (href.match(/(?:notice_id|nego_id)=(\d+)/) || [])[0] || href;
    notices.push({
      id: id.replace("=", "-"),
      title: readableTitle(title),
      reference: cells["ref no"] || "",
      process,
      country: OFFICES[code],
      buyer: `UNDP ${OFFICES[code]}`,
      deadline,
      sourceUrl: `${BASE}${href}`,
    });
  }
  return notices;
}

function buildScoringPrompt(profile, notices) {
  const lines = notices.map((t, i) => `${i} | ${t.title} | ${t.process} | ${t.buyer}`).join("\n");
  return `You are a bid advisor for JV ALMA CIS, a Kenyan company (Italian parent
company) with business units in construction, facility management, embassy &
diplomatic facilities, agribusiness, information technology, oil & gas
inspection services and human resources, which also builds its own software
platforms. It has NO experience in solar / photovoltaic / energy generation.
Company profile:

${profile}

Below are open UNDP procurement notices in East Africa (index | title |
process | office). For EACH give a fit score (0-100) for how well it matches
what the company actually does. Be strict: goods it doesn't deal in
(vehicles, medical supplies, fuel, food, printing), solar / energy
generation, travel and events should score low; building works, facility
management, ICT systems and software, GIS / data, and agribusiness work it
can deliver should score higher.
Score noticeably higher (and say so in the reason) when a tender closely resembles
one of the company's past projects listed in the profile above (e.g. embassy or
diplomatic-residence renovation, roofing, building works for foreign missions, an
AICS-type agribusiness programme) — proven track record wins bids.
Give a one-sentence reason.

Notices:
${lines}

Return ONLY a JSON array with one object per notice:
[{"index": number, "fitScorePercent": number, "fitReasoning": string}]
No commentary, no markdown fences.`;
}

const SOURCE = {
  key: "undp",
  label: "UNDP",
  memoryCollection: SCORED_COLLECTION,
  tags: ["undp", "donor-funded"],
  fundedBy: "UNDP",
  tenderSourceCategory: "unAgency",
  externalIdPrefix: "undp",
  descriptionFor: (t) => `UNDP procurement notice — ${t.process}. ${t.buyer} country office.${t.reference ? ` Ref ${t.reference}.` : ""}`,
  scoringPrompt: buildScoringPrompt,
  restoredReason: () => "UNDP procurement — restored from public-buyer archive",
};

async function fetchOpenNotices({ fetchImpl = fetchPageImpl, now = new Date() } = {}) {
  const res = await fetchImpl(LIST_URL, { redirect: "follow", headers: { "User-Agent": BROWSER_UA } });
  if (!res.ok) throw new Error(`UNDP notices HTTP ${res.status}`);
  return parseNotices(await res.text(), now);
}

/** Full run. Returns counts {fetched, alreadyScored, scored, created, restored, quiet}. */
async function runUndpDiscovery({ db, admin, buildProfile, scoreBatch, fetchImpl, now = new Date(), logger = console, quiet }) {
  const items = await fetchOpenNotices({ fetchImpl, now });
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
  });
}

module.exports = { parseUndpDeadline, parseNotices, buildScoringPrompt, fetchOpenNotices, runUndpDiscovery, OFFICES };
