const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { notifyAllUsers } = require("./matchScorePushNotification");
const { fetchPageImpl } = require("./lib/fetchPage");
const { mainText, hashText } = require("./callPageWatcher");
const { computeEligibility, loadCompanyFacts } = require("./grantEligibility");
const { outOfScopeReason } = require("./lib/scopePolicy");

/**
 * Funder watchlist: the pages of foundations, prize funds, accelerators and
 * donor innovation funds that run recurring calls JVA could apply to (the
 * kind of list Synnefa publishes monthly). AI web search finds these only
 * occasionally, and the EU portal doesn't carry them, so each funder's own
 * page is checked daily.
 *
 * Unlike callPageWatcher (one call per page, fixed deadline), a funder page
 * may list several calls, and many funders accept applications on a
 * rolling basis. Flow per page: hash the text; unchanged → nothing (no AI
 * cost). Changed → the AI lists the calls open today; each new one gets an
 * eligibility check (grantEligibility.js), is saved as an opportunity, and —
 * unless JVA isn't eligible — pushes a "New call open" alert to everyone.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

/**
 * Pages to watch. Add an entry to watch another funder. Checked to load
 * without a browser (GSMA and DIV block automated visits — the wider AI
 * search themes in index.js cover those).
 */
const FUNDER_PAGES = [
  {
    key: "ai-for-good",
    url: "https://aiforgood.itu.int/about-ai-for-good/innovation-factory/",
    name: "AI for Good Innovation Factory (ITU)",
    client: "ITU — AI for Good",
    kind: "programme",
  },
  {
    key: "fid",
    url: "https://fundinnovation.dev/en/launch-project",
    name: "Fund for Innovation in Development (FID)",
    client: "Fund for Innovation in Development",
    kind: "grant",
  },
  {
    key: "unicef-venture-fund",
    url: "https://www.unicefventurefund.org/",
    name: "UNICEF Venture Fund",
    client: "UNICEF Office of Innovation",
    kind: "grant",
  },
  {
    key: "global-innovation-fund",
    url: "https://www.globalinnovation.fund/apply-for-funding",
    name: "Global Innovation Fund",
    client: "Global Innovation Fund",
    kind: "grant",
  },
  {
    key: "aecf",
    url: "https://www.aecfafrica.org/",
    name: "AECF (Africa Enterprise Challenge Fund)",
    client: "AECF",
    kind: "grant",
  },
  {
    key: "google-startups-africa",
    url: "https://startup.google.com/programs/accelerator/africa/",
    name: "Google for Startups Accelerator: Africa",
    client: "Google for Startups",
    kind: "programme",
  },
  {
    key: "wilkes-climate-prize",
    url: "https://wilkescenter.utah.edu/prize/",
    name: "Wilkes Climate Prize",
    client: "Wilkes Center for Climate Science & Policy",
    kind: "grant",
  },
  {
    key: "kenya-cic",
    url: "https://www.kenyacic.org/",
    name: "Kenya Climate Innovation Center",
    client: "Kenya Climate Innovation Center",
    kind: "programme",
  },
  {
    key: "ashden-awards",
    url: "https://www.ashden.org/awards/",
    name: "Ashden Awards",
    client: "Ashden",
    kind: "grant",
  },
  {
    key: "grand-challenges-canada",
    url: "https://grandchallenges.ca/funding-opportunities/",
    name: "Grand Challenges Canada",
    client: "Grand Challenges Canada",
    kind: "grant",
  },
  {
    key: "challenge-works",
    url: "https://www.challenges.org/",
    name: "Challenge Works (Nesta) prizes",
    client: "Challenge Works — Nesta",
    kind: "grant",
  },
];

const STATE_COLLECTION = "watchedFunderPages";

function buildCallsPrompt(page, text, now) {
  return `Today is ${now.toISOString().slice(0, 10)}. Below is the text of the web page
of "${page.name}". List every funding call, prize, challenge or programme on
this page that is OPEN FOR APPLICATIONS TODAY — either with a submission
deadline that has not passed, or accepting applications on a rolling basis.
Ignore past/closed rounds, winners announcements, news and events.

Page text:
"""
${text.slice(0, 15000)}
"""

Return ONLY a JSON object:
{
  "calls": [
    {
      "name": string (the call's own name, e.g. "Energy Transition Challenge Fund — Kenya window"),
      "deadline": string | null (ISO 8601 date of the submission deadline; null if rolling or not stated),
      "rolling": boolean (true if applications are accepted on a rolling / continuous basis),
      "applyUrl": string (link to the call or application page if shown on this page; "" if not),
      "summary": string (2-3 sentences: who can apply, what is funded/offered, how much)
    }
  ]
}
Return {"calls": []} if nothing is open. No commentary, no markdown fences.`;
}

/** Lower-case words of a title, for loose duplicate matching. */
function titleWords(title) {
  return new Set(
    String(title || "")
      .toLowerCase()
      .replace(/[^a-z0-9 ]+/g, " ")
      .split(/\s+/)
      .filter((w) => w.length > 2),
  );
}

/**
 * True if two titles share most of their meaningful words, measured against
 * the longer one. Words in [ignore] (the funder's own name) are left out,
 * so "AECF — Energy window" and "AECF — Women window" don't look alike
 * just because both carry the funder's name.
 */
function similarTitles(a, b, ignore = new Set()) {
  const wa = new Set([...titleWords(a)].filter((w) => !ignore.has(w)));
  const wb = new Set([...titleWords(b)].filter((w) => !ignore.has(w)));
  if (wa.size === 0 || wb.size === 0) return false;
  let shared = 0;
  for (const w of wa) if (wb.has(w)) shared += 1;
  return shared / Math.max(wa.size, wb.size) >= 0.6;
}

/**
 * True if [existingTitle] (an opportunity already saved at the same link)
 * is this [callName] from [page]. A call whose name is just the funder's
 * name is the funder's single main call, so anything at that link is it.
 */
function isSameCall(existingTitle, callName, page) {
  const funderWords = titleWords(page.name);
  const callSpecific = [...titleWords(callName)].filter((w) => !funderWords.has(w));
  if (callSpecific.length === 0) return true;
  return similarTitles(existingTitle, callName, funderWords);
}

function slug(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

/**
 * Pure: the open calls worth saving from the AI's [extraction] — valid
 * names, and either rolling or with a deadline still ahead. Each gets its
 * stable externalId (one opportunity per funder + call + deadline year).
 */
function openCalls(page, extraction, now) {
  const calls = Array.isArray(extraction?.calls) ? extraction.calls : [];
  const result = [];
  for (const c of calls) {
    const name = typeof c?.name === "string" ? c.name.trim() : "";
    if (!name) continue;
    let deadline = null;
    if (c.deadline) {
      const d = new Date(c.deadline);
      if (!Number.isNaN(d.getTime())) deadline = d;
    }
    if (deadline && deadline <= now) continue;
    const rolling = !deadline && c.rolling === true;
    if (!deadline && !rolling) continue;
    const applyUrl = typeof c.applyUrl === "string" && /^https?:\/\//.test(c.applyUrl) ? c.applyUrl : page.url;
    result.push({
      name,
      deadline,
      rolling,
      applyUrl,
      summary: typeof c.summary === "string" ? c.summary.trim() : "",
      externalId: `funder:${page.key}:${slug(name)}:${deadline ? deadline.getUTCFullYear() : "rolling"}`,
    });
  }
  return result;
}

/**
 * Checks one funder page. Dependencies are injected so the flow is
 * testable. Returns {status, created} — status "unchanged" | "checked" |
 * "fetch failed (…)".
 */
async function checkFunderPage(
  page,
  { db, extract, fetchImpl = fetchPageImpl, notify = notifyAllUsers, now = new Date(), facts, quiet = false },
) {
  const res = await fetchImpl(page.url, {
    redirect: "follow",
    headers: { "User-Agent": "Mozilla/5.0 (compatible; OpportunityTracker/1.0)" },
  });
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

  // The first ever look at a page only records what's open (no alert per
  // call) — otherwise adding a funder would alert everything it lists at once.
  const silent = quiet || !state.contentHash;
  const calls = openCalls(page, await extract(buildCallsPrompt(page, text, now)), now);
  const companyFacts = facts || (await loadCompanyFacts(db));
  let created = 0;

  for (const call of calls) {
    const existing = await db.collection("opportunities").where("externalId", "==", call.externalId).limit(1).get();
    if (!existing.empty) continue;
    const title = similarTitles(call.name, page.name) ? call.name : `${page.name} — ${call.name}`;
    // Work JVA doesn't do (e.g. solar) — not saved, no alert.
    if (outOfScopeReason({ title })) continue;
    // Already found another way (AI search / EU portal) — same link and a similar title.
    const sameLink = await db.collection("opportunities").where("sourceUrl", "==", call.applyUrl).get();
    if (sameLink.docs.some((d) => isSameCall(d.data().title, call.name, page))) {
      continue;
    }

    const draft = {
      title,
      description: call.summary,
      sourceUrl: call.applyUrl,
      client: page.client,
      deadline: call.deadline ? Timestamp.fromDate(call.deadline) : null,
      kind: page.kind,
    };
    let eligibility = {};
    try {
      eligibility = await computeEligibility(draft, {
        extract,
        facts: companyFacts,
        text: call.applyUrl === page.url ? text.slice(0, 12000) : undefined,
        fetchImpl,
        now,
      });
    } catch (e) {
      logger.warn(`funderWatchlist: eligibility check failed for ${call.externalId} — will retry later: ${e.message}`);
    }

    const ref = await db.collection("opportunities").add({
      ...draft,
      sourceUrlVerified: true,
      sourceUrlVerifiedAt: ts,
      sourceUrlIsFallback: false,
      status: "discovered",
      fitScorePercent: typeof eligibility.eligibilityFitScore === "number" ? eligibility.eligibilityFitScore : 0,
      fitReasoning: `On the funder watchlist — ${page.name}.`,
      tags: ["funder-watchlist", page.key, ...(call.rolling ? ["rolling"] : [])],
      rolling: call.rolling,
      externalId: call.externalId,
      watched: true,
      // This watcher sends its own "New call open" push below.
      suppressNotification: true,
      discoveredAt: ts,
      updatedAt: ts,
      ...eligibility,
    });
    created += 1;

    // [silent]: first look at this page (or quiet run) — saved, no push.
    if (!silent && eligibility.eligibility !== "notEligible") {
      await notify({
        type: "watchedCallOpen",
        opportunityId: ref.id,
        opportunityTitle: title,
        deadline: call.deadline ? call.deadline.toISOString() : null,
      });
    }
  }

  await stateRef.set(
    {
      url: page.url,
      contentHash,
      lastCheckedAt: ts,
      lastChangedAt: ts,
      lastOpenCalls: calls.map((c) => c.name),
    },
    { merge: true },
  );
  return { status: "checked", created };
}

/** Checks every funder page; one page failing never stops the others. */
async function checkAllFunderPages(deps) {
  const facts = deps.facts || (await loadCompanyFacts(deps.db));
  const results = {};
  for (const page of FUNDER_PAGES) {
    try {
      results[page.key] = await checkFunderPage(page, { ...deps, facts });
    } catch (e) {
      logger.error(`funderWatchlist: ${page.key} failed`, e);
      results[page.key] = { status: "error", created: 0 };
    }
  }
  logger.info(`funderWatchlist: ${JSON.stringify(results)}`);
  return results;
}

module.exports = {
  FUNDER_PAGES,
  buildCallsPrompt,
  openCalls,
  similarTitles,
  isSameCall,
  checkFunderPage,
  checkAllFunderPages,
  /** Builds the scheduled function; [extract] comes from index.js (Gemini). */
  makeScheduledFunderWatch: (extract) =>
    onSchedule({ schedule: "every day 07:45", timeZone: "Africa/Nairobi", timeoutSeconds: 540 }, async () => {
      await checkAllFunderPages({ db: admin.firestore(), extract });
    }),
};
