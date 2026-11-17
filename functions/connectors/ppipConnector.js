/**
 * Kenya Public Procurement Information Portal (PPIP, tenders.go.ke)
 * connector — reads every active national / county tender straight from
 * the portal's public JSON API (`/api/active-tenders`, the same endpoint the
 * portal's own tender list uses; no login). Titles, references, procuring
 * entities and closing dates come from the official source; the AI is used
 * only to score fit against the company profile.
 *
 * PRIVACY: API records embed the posting officers' personal details
 * (`created_by`, `team_members`, `directors`, ...). Only the fields listed
 * in [toTender] are ever read — nothing personal is stored.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const { isDonorFunded } = require("../lib/buyerPolicy");

const API_URL = "https://tenders.go.ke/api/active-tenders";
const TENDER_PAGE = "https://tenders.go.ke/tenders";
const PER_PAGE = 100;
const MAX_PAGES = 30;

/** Firestore collection remembering every PPIP tender id already scored. */
const SCORED_COLLECTION = "ppipScoredTenders";
const MIN_FIT_SCORE = 50;
const SCORING_BATCH_SIZE = 80;

const CATEGORY_LABELS = { 1: "Goods", 2: "Works", 3: "Services", 4: "Consultancy" };

/** "2026-11-17 11:00:00" (Nairobi local time, as PPIP returns it) -> Date. */
function parseNairobiTime(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}/.test(value)) return null;
  const iso = `${value.trim().replace(" ", "T")}${value.length <= 10 ? "T00:00:00" : ""}+03:00`;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** "TENDER FOR FENCING OF ATC" -> "Tender for Fencing of ATC"-style readable case. */
function readableTitle(title) {
  const t = String(title || "").replace(/\s+/g, " ").trim();
  if (t !== t.toUpperCase() || !/[A-Z]{4,}/.test(t)) return t;
  const small = new Set(["a", "an", "and", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"]);
  return t
    .toLowerCase()
    .split(" ")
    .map((w, i) => {
      if (/\d/.test(w) || /^\W*[a-z]{1,3}\W*$/.test(w) && /^(ict|ttc|atc|kmtc|ttc|ups|cctv|hvac)$/.test(w.replace(/\W/g, ""))) return w.toUpperCase();
      if (i > 0 && small.has(w)) return w;
      return w.charAt(0).toUpperCase() + w.slice(1);
    })
    .join(" ");
}

/**
 * The only fields read from a PPIP record. Returns null for records
 * without an id/title, terminated tenders, or ones already closed.
 */
function toTender(record, now) {
  if (!record || !record.id || !record.title || record.terminated) return null;
  const closeAt = parseNairobiTime(record.close_at);
  if (closeAt && closeAt <= now) return null;
  const categoryId = record.procurement_category_id;
  return {
    id: String(record.id),
    title: readableTitle(record.title),
    reference: record.tender_ref ? String(record.tender_ref) : null,
    entity: record.pe?.name ? String(record.pe.name).trim() : null,
    entityIsCounty: record.pe?.type?.code === "countyGovernment",
    category: record.procurement_category?.title || CATEGORY_LABELS[categoryId] || null,
    method: record.procurement_method?.title || null,
    venue: record.venue ? String(record.venue).trim() : null,
    agpo: record.is_agpo === 1 || record.is_agpo === true,
    closeAt,
    sourceUrl: `${TENDER_PAGE}/${record.id}`,
  };
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * GET one page, politely: the portal rate-limits (HTTP 429) clients that
 * page quickly, so a 429 waits (Retry-After if given, else 5s, 15s, 45s)
 * and retries. Returns the parsed body, or null if still refused.
 */
async function fetchPageJson(url, { fetchImpl, wait }) {
  const delays = [5000, 15000, 45000];
  for (let attempt = 0; ; attempt++) {
    const res = await fetchImpl(url, {
      headers: { Accept: "application/json", "User-Agent": "Mozilla/5.0 (compatible; OpportunityTracker/1.0)" },
    });
    if (res.ok) return res.json();
    if (res.status !== 429 || attempt >= delays.length) {
      if (res.status === 429) return null;
      throw new Error(`PPIP API returned ${res.status}`);
    }
    const retryAfter = Number(res.headers?.get?.("retry-after"));
    await wait(Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : delays[attempt]);
  }
}

/**
 * Fetches every active tender (paged), keeping only open ones, pausing
 * between pages. If the portal keeps refusing part-way, the pages already
 * fetched are returned (the rest are picked up on the next daily run).
 */
async function fetchActiveTenders({
  fetchImpl = fetch,
  now = new Date(),
  wait = sleep,
  pageDelayMs = 2500,
  logger = console,
} = {}) {
  const tenders = [];
  for (let page = 1; page <= MAX_PAGES; page++) {
    if (page > 1) await wait(pageDelayMs);
    const body = await fetchPageJson(`${API_URL}?perpage=${PER_PAGE}&page=${page}`, { fetchImpl, wait });
    if (body === null) {
      if (page === 1) throw new Error("PPIP API is rate-limiting (429) — try again later");
      logger.warn?.(`fetchActiveTenders: rate-limited at page ${page}; continuing with ${tenders.length} tenders`);
      break;
    }
    for (const record of body?.data || []) {
      const t = toTender(record, now);
      if (t) tenders.push(t);
    }
    if (!body?.last_page || page >= body.last_page) break;
  }
  return tenders;
}

function buildPpipScoringPrompt(profile, tenders) {
  const lines = tenders
    .map(
      (t, i) =>
        `${i} | ${t.title} | ${t.entity || "?"} | ${t.category || "?"}${t.venue ? ` | ${t.venue}` : ""}${t.agpo ? " | AGPO-reserved" : ""}`,
    )
    .join("\n");
  return `You are a bid advisor for JV ALMA CIS, a Kenyan company with business
units in construction, facility management, agribusiness, information
technology and human resources, which also builds its own software
platforms. Company profile:

${profile}

Below are open Kenyan public tenders (index | title | procuring entity |
category | venue). For EACH tender give a fit score (0-100) for how well it
matches what the company actually does. Be strict: generic supply of goods
the company doesn't deal in (fuel, food, drugs, stationery, vehicles) should
score low; construction works, facility management (cleaning, security,
maintenance), ICT systems and agribusiness work it can deliver should score
higher. Give a one-sentence reason.

Tenders:
${lines}

Return ONLY a JSON array with one object per tender:
[{"index": number, "fitScorePercent": number, "fitReasoning": string}]
No commentary, no markdown fences.`;
}

/**
 * Full run: fetch active tenders, skip ones already scored, score the rest
 * in batches with [scoreBatch], save those scoring >= MIN_FIT_SCORE, and
 * remember every scored id. With [quiet], saved tenders are marked
 * `suppressNotification` (first bulk import). Returns counts.
 */
async function runPpipDiscovery({
  db,
  admin,
  buildProfile,
  scoreBatch,
  fetchImpl = fetch,
  now = new Date(),
  logger = console,
  quiet = false,
  wait,
}) {
  // Buyer policy: everything on PPIP is a Kenyan public body, so only
  // donor-funded tenders are considered (see lib/buyerPolicy.js).
  const allTenders = await fetchActiveTenders({ fetchImpl, now, logger, ...(wait ? { wait } : {}) });
  const tenders = allTenders.filter((t) => isDonorFunded(`${t.title} ${t.entity || ""}`));

  const seen = new Set();
  for (let i = 0; i < tenders.length; i += 100) {
    const refs = tenders.slice(i, i + 100).map((t) => db.collection(SCORED_COLLECTION).doc(t.id));
    (await db.getAll(...refs)).forEach((snap) => {
      if (snap.exists) seen.add(snap.id);
    });
  }
  const fresh = tenders.filter((t) => !seen.has(t.id));
  if (fresh.length === 0) {
    logger.info(`runPpipDiscovery: ${allTenders.length} active, ${tenders.length} donor-funded, all already scored`);
    return { fetched: tenders.length, alreadyScored: seen.size, scored: 0, created: 0 };
  }

  const profile = await buildProfile();
  const Timestamp = admin.firestore.Timestamp;
  let scored = 0;
  let created = 0;
  for (let i = 0; i < fresh.length; i += SCORING_BATCH_SIZE) {
    const batch = fresh.slice(i, i + SCORING_BATCH_SIZE);
    let results;
    try {
      results = await scoreBatch(buildPpipScoringPrompt(profile, batch));
    } catch (e) {
      logger.error(`runPpipDiscovery: scoring batch ${i / SCORING_BATCH_SIZE + 1} failed`, e);
      continue;
    }
    if (!Array.isArray(results)) continue;
    scored += batch.length;

    const ts = Timestamp.fromDate(now);
    const resultByIndex = new Map(results.map((r) => [r?.index, r]));
    const remember = db.batch();
    for (const [index, t] of batch.entries()) {
      const r = resultByIndex.get(index) || {};
      const score = Math.max(0, Math.min(100, Math.round(Number(r.fitScorePercent) || 0)));
      remember.set(db.collection(SCORED_COLLECTION).doc(t.id), { fitScorePercent: score, scoredAt: ts });
      if (score < MIN_FIT_SCORE) continue;

      await db.collection("opportunities").add({
        title: t.title,
        description: [
          `${t.category || "Public"} tender by ${t.entity || "a Kenyan public entity"}.`,
          t.venue ? `Venue: ${t.venue}.` : "",
          t.method ? `Method: ${t.method}.` : "",
          t.agpo ? "Reserved for AGPO-registered firms (youth, women, PWD)." : "",
        ].filter(Boolean).join(" "),
        sourceUrl: t.sourceUrl,
        sourceUrlVerified: true,
        sourceUrlVerifiedAt: ts,
        sourceUrlIsFallback: false,
        client: t.entity,
        procuringOrganization: t.entity,
        tenderReferenceNumber: t.reference,
        deadline: t.closeAt ? Timestamp.fromDate(t.closeAt) : null,
        status: "discovered",
        fitScorePercent: score,
        fitReasoning: typeof r.fitReasoning === "string" ? r.fitReasoning : "",
        tags: ["ppip", ...(t.agpo ? ["agpo"] : [])],
        kind: "tender",
        tenderSourceCategory: t.entityIsCounty ? "countyGovernment" : "governmentAgency",
        geographyPriority: "kenya",
        externalId: `ppip:${t.id}`,
        ...(quiet ? { suppressNotification: true } : {}),
        discoveredAt: ts,
        updatedAt: ts,
      });
      created += 1;
    }
    await remember.commit();
  }

  logger.info(
    `runPpipDiscovery: ${tenders.length} active, ${seen.size} already scored, ${scored} scored, ` +
      `${created} created (fit >= ${MIN_FIT_SCORE})${quiet ? " [quiet]" : ""}`,
  );
  return { fetched: tenders.length, alreadyScored: seen.size, scored, created };
}

module.exports = {
  toTender,
  parseNairobiTime,
  readableTitle,
  fetchActiveTenders,
  buildPpipScoringPrompt,
  runPpipDiscovery,
  MIN_FIT_SCORE,
};
