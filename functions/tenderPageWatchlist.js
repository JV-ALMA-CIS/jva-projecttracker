const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { fetchPageImpl } = require("./lib/fetchPage");
const { mainText, hashText } = require("./callPageWatcher");
const { openCalls, isSameCall } = require("./funderWatchlist");
const { outOfScopeReason } = require("./lib/scopePolicy");
const { isAllowedCountry } = require("./opportunityRelevance");

/**
 * Tender page watchlist: pages where a buyer lists its own open tenders as
 * text (Italian Embassy Nairobi, the EU Delegation to Kenya on EEAS, Kenya
 * Red Cross). AI web search finds these late or not at all; reading the
 * page directly gets them the day they're posted.
 *
 * Daily: hash the page text; unchanged → nothing (no AI cost). Changed →
 * the AI lists the tenders open today; each new one is saved UNSCORED, so
 * onOpportunityCreated sorts it into a business unit, runs Match Analysis
 * and alerts everyone if it scores >= 70%. The first ever look at a page
 * saves what's open with `scoreQuietly` (scored, but no alert), so adding a
 * page doesn't alert its whole backlog at once.
 *
 * Pages that load their list by script (EACOP, AICS) or block automated
 * visits (Save the Children, UN-Habitat) can't be read this way — the AI
 * search sources cover those.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const TENDER_PAGES = [
  {
    key: "italian-embassy-nairobi",
    url: "https://ambnairobi.esteri.it/it/amministrazione-trasparente/bandi-di-gara-e-contratti/",
    name: "Italian Embassy Nairobi",
    client: "Embassy of Italy, Nairobi",
    tenderSourceCategory: "governmentAgency",
    // Everything on this page is for Nairobi unless it says otherwise.
    local: true,
  },
  {
    key: "eu-delegation-kenya",
    url: "https://www.eeas.europa.eu/eeas/tenders_en?fulltext=Kenya",
    name: "EU Delegation to Kenya (EEAS)",
    client: "European Union Delegation to Kenya",
    tenderSourceCategory: "developmentPartner",
  },
  {
    key: "kenya-red-cross",
    url: "https://redcross.or.ke/tenders/",
    name: "Kenya Red Cross",
    client: "Kenya Red Cross Society",
    tenderSourceCategory: "ngo",
    local: true,
  },
];

const STATE_COLLECTION = "watchedTenderPages";

const ALLOWED_COUNTRIES = new Set(["kenya", "uganda", "tanzania", "rwanda", "burundi"]);

/**
 * Pure: only tenders delivered in Kenya, Uganda, Tanzania, Rwanda or
 * Burundi. EEAS lists EU Delegation tenders worldwide (Serbia, Zimbabwe,
 * Paraguay, ...), so the AI's stated country decides; with no country
 * stated, a "local" page's tender counts as local and any other needs a
 * place name in its own title/summary.
 */
function isEastAfricanTender(call, page) {
  const country = String(call?.country || "").trim().toLowerCase();
  if (country) return [...ALLOWED_COUNTRIES].some((c) => country.includes(c));
  if (page.local) return true;
  return isAllowedCountry({ title: call?.name, description: call?.summary });
}
const BROWSER_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

function buildTendersPrompt(page, text, now) {
  return `Today is ${now.toISOString().slice(0, 10)}. Below is the text of the tenders page of
"${page.name}" (it may be in Italian, French or English). List every tender,
RFQ, RFP, call for tenders or expression of interest on it that is STILL OPEN
today (its submission deadline has not passed). Ignore closed ones, awards,
clarifications/addenda on their own, prequalification results, jobs and news.
If the page shows only a publication date and no deadline, skip the item.

Page text:
"""
${text.slice(0, 15000)}
"""

Return ONLY a JSON object:
{
  "calls": [
    {
      "name": string (the tender's title in English — translate if needed; keep any reference number),
      "deadline": string (ISO 8601 date of the submission deadline),
      "rolling": false,
      "applyUrl": string (link to the tender's own page if shown; "" if not),
      "country": string (the country where the work / service is delivered, e.g. "Kenya"; "" if not stated),
      "summary": string (1-2 sentences: what is being bought, where, any key requirement)
    }
  ]
}
Return {"calls": []} if nothing is open. No commentary, no markdown fences.`;
}

/**
 * Checks one page. Dependencies injected for testing. Returns
 * {status, created} — status "unchanged" | "checked" | "fetch failed (…)".
 */
async function checkTenderPage(page, { db, extract, fetchImpl = fetchPageImpl, now = new Date() }) {
  const res = await fetchImpl(page.url, { redirect: "follow", headers: { "User-Agent": BROWSER_UA } });
  if (!res.ok) return { status: `fetch failed (${res.status})`, created: 0 };
  const text = mainText(await res.text());
  const contentHash = hashText(text);
  const Timestamp = admin.firestore.Timestamp;
  const ts = Timestamp.fromDate(now);

  const stateRef = db.collection(STATE_COLLECTION).doc(page.key);
  const state = (await stateRef.get()).data() || {};
  if (state.contentHash === contentHash) {
    await stateRef.set({ lastCheckedAt: ts }, { merge: true });
    return { status: "unchanged", created: 0 };
  }
  const firstLook = !state.contentHash;

  const extraction = await extract(buildTendersPrompt(page, text, now));
  const inRegion = (Array.isArray(extraction?.calls) ? extraction.calls : []).filter((c) =>
    isEastAfricanTender(c, page),
  );
  const calls = openCalls(page, { calls: inRegion }, now).filter((c) => !c.rolling);
  let created = 0;
  for (const call of calls) {
    if (outOfScopeReason({ title: call.name })) continue;
    const externalId = call.externalId.replace(/^funder:/, "tenderpage:");
    const existing = await db.collection("opportunities").where("externalId", "==", externalId).limit(1).get();
    if (!existing.empty) continue;
    const sameLink = await db.collection("opportunities").where("sourceUrl", "==", call.applyUrl).get();
    if (sameLink.docs.some((d) => isSameCall(d.data().title, call.name, page))) continue;

    await db.collection("opportunities").add({
      title: call.name,
      description: call.summary,
      sourceUrl: call.applyUrl,
      sourceUrlVerified: true,
      sourceUrlVerifiedAt: ts,
      sourceUrlIsFallback: false,
      client: page.client,
      deadline: call.deadline ? Timestamp.fromDate(call.deadline) : null,
      status: "discovered",
      fitScorePercent: 0,
      tags: ["watched-listing", "tender-page", page.key],
      kind: "tender",
      tenderSourceCategory: page.tenderSourceCategory,
      geographyPriority: "kenya",
      externalId,
      // First look: scored by onOpportunityCreated, but no alert.
      ...(firstLook ? { scoreQuietly: true } : {}),
      discoveredAt: ts,
      updatedAt: ts,
    });
    created += 1;
  }

  await stateRef.set(
    { url: page.url, contentHash, lastCheckedAt: ts, lastChangedAt: ts, lastOpenTenders: calls.map((c) => c.name) },
    { merge: true },
  );
  return { status: "checked", created };
}

/** Checks every page; one page failing never stops the others. */
async function checkAllTenderPages(deps) {
  const results = {};
  for (const page of TENDER_PAGES) {
    try {
      results[page.key] = await checkTenderPage(page, deps);
    } catch (e) {
      logger.error(`tenderPageWatchlist: ${page.key} failed`, e);
      results[page.key] = { status: "error", created: 0 };
    }
  }
  logger.info(`tenderPageWatchlist: ${JSON.stringify(results)}`);
  return results;
}

module.exports = {
  TENDER_PAGES,
  isEastAfricanTender,
  buildTendersPrompt,
  checkTenderPage,
  checkAllTenderPages,
  /** Builds the scheduled function; [extract] comes from index.js (Gemini). */
  makeScheduledTenderPageWatch: (extract) =>
    onSchedule({ schedule: "every day 07:50", timeZone: "Africa/Nairobi", timeoutSeconds: 540 }, async () => {
      await checkAllTenderPages({ db: admin.firestore(), extract });
    }),
};
