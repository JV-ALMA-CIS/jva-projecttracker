/**
 * EU Funding & Tenders portal connector — reads every open / forthcoming EU
 * call for proposals (and cascade-funding call) straight from the portal's
 * public search API (the same "SEDIA" API the portal website uses; no key
 * needed). Unlike AI web search, every title, link and deadline here comes
 * from the official source, so nothing can be invented. The AI is used only
 * to score how well each call fits the company and whether a Kenyan
 * organisation can take part.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const SEARCH_URL = "https://api.tech.ec.europa.eu/search-api/prod/rest/search";
const PORTAL_BASE = "https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/opportunities";

/** Portal record types: 1 = call topic (call for proposals), 8 = cascade-funding call. */
const CALL_TYPES = ["1", "8"];
/** Portal status codes: forthcoming, open. */
const OPEN_STATUSES = ["31094501", "31094502"];

/**
 * Identifier prefixes of programmes that are effectively EU-internal or for
 * individuals — a Kenyan company can't realistically take part, so they're
 * dropped before any AI scoring. Everything else (mostly Horizon Europe,
 * where Kenya is eligible for funding as a low/middle-income country, plus
 * NDICI / Global Europe) goes to scoring.
 */
const EXCLUDED_PREFIXES = [
  "EDF", "CERV", "CREA", "ERASMUS", "ISF", "CEF", "JUST", "ERC", "HORIZON-MSCA",
  "EURATOM", "HORIZON-EURATOM", "LIFE", "SMP", "I3", "JTM", "EMFAF", "PPPA",
  "IMCAP", "IMREG", "AMIF", "BMVI", "UCPM", "PERI", "RFCS", "EUAF", "SOCPL",
  "AGRIP", "RENEWFM", "ESF", "EU4H", "DIGITAL", "ED",
];

function isExcludedIdentifier(identifier) {
  const id = String(identifier || "").toUpperCase();
  return EXCLUDED_PREFIXES.some((p) => id === p || id.startsWith(`${p}-`));
}

/** The public portal page for a call (the API sometimes returns raw .json data links). */
function portalUrlFor(identifier, type, apiUrl) {
  if (type === "8" && typeof apiUrl === "string" && apiUrl.includes("/competitive-calls-cs/")) {
    return apiUrl;
  }
  return `${PORTAL_BASE}/topic-details/${encodeURIComponent(identifier)}`;
}

const first = (v) => (Array.isArray(v) ? v[0] : v);

/**
 * Turns one API result into a call record, or null when it has no future
 * deadline (the "open" status filter still returns some long-closed
 * records, so the deadline is the real test) or is excluded.
 */
function toCall(result, type, now) {
  const m = result?.metadata || {};
  const identifier = first(m.identifier);
  const title = first(m.title);
  if (!identifier || !title || isExcludedIdentifier(identifier)) return null;

  const futureDeadlines = (m.deadlineDate || [])
    .map((d) => Date.parse(d))
    .filter((t) => Number.isFinite(t) && t > now.getTime());
  if (futureDeadlines.length === 0) return null;

  const budget = Number(first(m.budget));
  return {
    identifier,
    title: String(title).trim(),
    callTitle: first(m.callTitle) || null,
    type,
    deadline: new Date(Math.min(...futureDeadlines)),
    budget: Number.isFinite(budget) && budget > 0 ? budget : null,
    sourceUrl: portalUrlFor(identifier, type, result.url),
  };
}

async function searchPage({ type, pageNumber, fetchImpl }) {
  const form = new FormData();
  const json = (v) => new Blob([JSON.stringify(v)], { type: "application/json" });
  form.append(
    "query",
    json({ bool: { must: [{ terms: { type: [type] } }, { terms: { status: OPEN_STATUSES } }] } }),
  );
  form.append("languages", json(["en"]));
  // Without an explicit sort the API's paging is unstable (pages overlap /
  // skip records between requests); sorting by identifier makes it stable.
  form.append("sort", json({ field: "identifier", order: "ASC" }));
  const url = `${SEARCH_URL}?apiKey=SEDIA&text=***&pageSize=100&pageNumber=${pageNumber}`;
  const res = await fetchImpl(url, { method: "POST", body: form });
  if (!res.ok) throw new Error(`EU search API returned ${res.status}`);
  return res.json();
}

/**
 * Fetches every open/forthcoming call with a future deadline, deduplicated
 * by identifier (a call with several cut-off dates appears once, with its
 * soonest future deadline). At most [maxPages] pages of 100 per type.
 */
async function fetchOpenEuCalls({ fetchImpl = fetch, now = new Date(), maxPages = 20 } = {}) {
  const byId = new Map();
  for (const type of CALL_TYPES) {
    for (let pageNumber = 1; pageNumber <= maxPages; pageNumber++) {
      const page = await searchPage({ type, pageNumber, fetchImpl });
      const results = page?.results || [];
      for (const r of results) {
        const call = toCall(r, type, now);
        if (!call) continue;
        const existing = byId.get(call.identifier);
        if (!existing || call.deadline < existing.deadline) byId.set(call.identifier, call);
      }
      if (results.length < 100) break;
    }
  }
  return [...byId.values()];
}

/** Scoring prompt for one batch of calls (no web search — titles/IDs are authoritative). */
function buildEuScoringPrompt(profile, calls) {
  const lines = calls
    .map((c, i) => `${i} | ${c.identifier} | ${c.title}${c.callTitle && c.callTitle !== c.identifier ? ` (call: ${c.callTitle})` : ""} | deadline ${c.deadline.toISOString().slice(0, 10)}`)
    .join("\n");
  return `You are a funding advisor for JV ALMA CIS, a company registered and
headquartered in Kenya that builds its own software platforms and delivers
construction, agribusiness, facility-management and IT projects.
Company profile:

${profile}

Below are open EU funding calls (index | call identifier | title | deadline).
For EACH call decide:
- "kenyaEligible": can a Kenyan company take part AND receive funding?
  Horizon Europe: Kenya is on the list of low/middle-income countries
  automatically eligible for funding, usually as a partner in a consortium.
  Calls restricted to EU/associated-country entities are false.
- "fitScorePercent" (0-100): how well the call fits the company's platforms
  and experience. Be strict — most calls should score low.
- "kind": "programme" for accelerator / mentoring / cascade-support
  programmes, otherwise "grant".
- "fitReasoning": one or two sentences, naming the company platform or
  experience that fits (or why it doesn't).
- "eligibility": a short note on how a Kenyan company could take part
  (e.g. "Consortium partner; Kenya eligible for Horizon funding").

Calls:
${lines}

Return ONLY a JSON array with one object per call:
[{"index": number, "kenyaEligible": boolean, "fitScorePercent": number,
  "kind": "grant" | "programme", "fitReasoning": string, "eligibility": string}]
No commentary, no markdown fences.`;
}

/**
 * Firestore collection remembering every EU call identifier the AI has
 * scored (doc id = identifier). Server-only: no client rule exists, so
 * clients are denied by default.
 */
const SCORED_COLLECTION = "euFundingScoredCalls";

/** Minimum fit score for an EU call to be saved as an opportunity. */
const EU_MIN_FIT_SCORE = 50;
const SCORING_BATCH_SIZE = 80;

/**
 * Full run: fetch open calls, skip ones already saved (by `externalId`) or
 * already scored (SCORED_COLLECTION),
 * score the rest in batches with [scoreBatch] (an async fn taking a prompt
 * and returning parsed JSON — injected so this is testable without Vertex
 * AI), and save calls that are Kenya-eligible and score >= EU_MIN_FIT_SCORE.
 * With [quiet], saved calls are marked `suppressNotification: true` so no
 * push goes out (used for the first bulk import of the whole EU catalogue).
 * Returns `{ fetched, alreadySaved, scored, created }`.
 */
async function runEuFundingDiscovery({
  db,
  admin,
  buildProfile,
  scoreBatch,
  fetchImpl = fetch,
  now = new Date(),
  logger = console,
  quiet = false,
}) {
  const calls = await fetchOpenEuCalls({ fetchImpl, now });

  const ids = calls.map((c) => c.identifier);
  const saved = new Set();
  for (let i = 0; i < ids.length; i += 30) {
    const snap = await db
      .collection("opportunities")
      .where("externalId", "in", ids.slice(i, i + 30))
      .get();
    snap.docs.forEach((d) => saved.add(d.data().externalId));
  }

  // Calls the AI has already scored (saved or not) are never re-scored:
  // re-scoring the rejected ones every week costs AI calls and, since
  // scores vary slightly between runs, lets borderline calls drift in.
  const alreadyScored = new Set();
  const unsaved = ids.filter((id) => !saved.has(id));
  for (let i = 0; i < unsaved.length; i += 100) {
    const refs = unsaved.slice(i, i + 100).map((id) => db.collection(SCORED_COLLECTION).doc(id));
    const snaps = await db.getAll(...refs);
    snaps.forEach((snap) => {
      if (snap.exists) alreadyScored.add(snap.id);
    });
  }

  const fresh = calls.filter((c) => !saved.has(c.identifier) && !alreadyScored.has(c.identifier));
  if (fresh.length === 0) {
    return { fetched: calls.length, alreadySaved: saved.size, scored: 0, created: 0 };
  }

  const profile = await buildProfile();
  let created = 0;
  let scored = 0;
  for (let i = 0; i < fresh.length; i += SCORING_BATCH_SIZE) {
    const batch = fresh.slice(i, i + SCORING_BATCH_SIZE);
    let results;
    try {
      results = await scoreBatch(buildEuScoringPrompt(profile, batch));
    } catch (e) {
      logger.error(`runEuFundingDiscovery: scoring batch ${i / SCORING_BATCH_SIZE + 1} failed`, e);
      continue;
    }
    if (!Array.isArray(results)) continue;
    scored += batch.length;

    // Remember every call in this batch as scored, with its result.
    const scoredAt = admin.firestore.Timestamp.now();
    const resultByIndex = new Map(results.map((r) => [r?.index, r]));
    const writes = db.batch();
    batch.forEach((call, index) => {
      const r = resultByIndex.get(index) || {};
      writes.set(db.collection(SCORED_COLLECTION).doc(call.identifier), {
        fitScorePercent: Number(r.fitScorePercent) || 0,
        kenyaEligible: r.kenyaEligible === true,
        scoredAt,
      });
    });
    await writes.commit();

    for (const r of results) {
      const call = batch[r?.index];
      if (!call || r.kenyaEligible !== true) continue;
      const score = Math.max(0, Math.min(100, Math.round(Number(r.fitScorePercent) || 0)));
      if (score < EU_MIN_FIT_SCORE) continue;

      const ts = admin.firestore.Timestamp.now();
      await db.collection("opportunities").add({
        title: call.title,
        description: [
          call.callTitle && call.callTitle !== call.identifier ? `EU call: ${call.callTitle}.` : "EU funding call.",
          `Identifier: ${call.identifier}.`,
          r.eligibility ? `Eligibility: ${r.eligibility}` : "",
        ].filter(Boolean).join(" "),
        sourceUrl: call.sourceUrl,
        sourceUrlVerified: true,
        sourceUrlVerifiedAt: ts,
        sourceUrlIsFallback: false,
        client: "European Commission",
        deadline: admin.firestore.Timestamp.fromDate(call.deadline),
        estimatedBudget: call.budget,
        status: "discovered",
        fitScorePercent: score,
        fitReasoning: typeof r.fitReasoning === "string" ? r.fitReasoning : "",
        tags: ["eu-funding-tenders"],
        kind: r.kind === "programme" ? "programme" : "grant",
        eligibility: typeof r.eligibility === "string" ? r.eligibility : null,
        externalId: call.identifier,
        geographyPriority: "internationalStrategic",
        // Quiet import: onOpportunityCreated skips the push for this doc.
        ...(quiet ? { suppressNotification: true } : {}),
        discoveredAt: ts,
        updatedAt: ts,
      });
      created += 1;
    }
  }

  logger.info(
    `runEuFundingDiscovery: ${calls.length} open calls, ${saved.size} already saved, ` +
      `${scored} scored, ${created} created (Kenya-eligible, fit >= ${EU_MIN_FIT_SCORE})`,
  );
  return { fetched: calls.length, alreadySaved: saved.size, scored, created };
}

module.exports = {
  fetchOpenEuCalls,
  runEuFundingDiscovery,
  buildEuScoringPrompt,
  isExcludedIdentifier,
  toCall,
  portalUrlFor,
  EU_MIN_FIT_SCORE,
};
