const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const { notifyAllUsers } = require("./matchScorePushNotification");
const { fetchPageImpl } = require("./lib/fetchPage");

/**
 * Watches specific funding-call pages the company cares about (e.g. the
 * ESA / Kenya Space Agency ABIL open calls) and raises an opportunity + push
 * as soon as a new round opens or its deadline moves. These programmes
 * don't appear in any tender feed and AI web search rarely finds them, so
 * the page itself is the source of truth.
 *
 * Daily: each page's main text is hashed; if it hasn't changed since the
 * last check nothing else happens (no AI cost). When it changes, the AI
 * reads the text and reports whether a call is open and its deadline.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

/** Pages to watch. Add an entry to watch another programme's call page. */
const WATCHED_CALL_PAGES = [
  {
    key: "abil-explore",
    url: "https://abil.ksa.go.ke/explore/",
    name: "ABIL EXPLORE open call (ESA / Kenya Space Agency)",
    client: "Africa Business Innovation Lab — ESA / Kenya Space Agency",
    kind: "grant",
  },
  {
    key: "abil-invest",
    url: "https://abil.ksa.go.ke/invest/",
    name: "ABIL INVEST open call (ESA / Kenya Space Agency)",
    client: "Africa Business Innovation Lab — ESA / Kenya Space Agency",
    kind: "programme",
  },
];

const STATE_COLLECTION = "watchedCallPages";

/** The page's readable text (no scripts, styles, header, footer or nav). */
function mainText(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<(header|footer|nav)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&#8211;|&ndash;/g, "-")
    .replace(/&#8217;|&rsquo;/g, "'")
    .replace(/&[a-z#0-9]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function hashText(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function buildExtractionPrompt(page, text, now) {
  return `Today is ${now.toISOString().slice(0, 10)}. Below is the text of the
web page for "${page.name}". Decide whether a call for applications is
CURRENTLY OPEN (accepting submissions today, with a submission deadline
that has not passed). Use the latest deadline the page states, including
any extension.

Page text:
"""
${text.slice(0, 15000)}
"""

Return ONLY a JSON object:
{
  "isOpen": boolean,
  "roundName": string (e.g. "2027 evaluation round"; "" if unknown),
  "deadline": string | null (ISO 8601 date-time of the submission deadline, or null),
  "summary": string (2-3 sentences: who can apply, what is funded/offered, the deadline)
}
No commentary, no markdown fences.`;
}

/**
 * Pure decision step: given the AI's [extraction], the page, any
 * [existing] opportunity for this page's current round, and [now], returns
 * one of:
 *   { action: "none" }
 *   { action: "create", deadline }
 *   { action: "extend", deadline }   (same round, deadline moved)
 */
function decide(extraction, existing, now) {
  if (!extraction || extraction.isOpen !== true || !extraction.deadline) return { action: "none" };
  const deadline = new Date(extraction.deadline);
  if (Number.isNaN(deadline.getTime()) || deadline <= now) return { action: "none" };
  if (!existing) return { action: "create", deadline };
  const existingDeadline = existing.deadline?.toDate ? existing.deadline.toDate() : new Date(existing.deadline);
  if (Math.abs(existingDeadline.getTime() - deadline.getTime()) > 60 * 60 * 1000) {
    return { action: "extend", deadline };
  }
  return { action: "none" };
}

/**
 * Checks one page. Dependencies are injected so the flow is testable:
 * [fetchImpl] fetch, [extract] async (prompt) -> parsed JSON, [db]
 * Firestore, [notify] notifyAllUsers. Returns a short result string.
 */
async function checkPage(page, { db, fetchImpl = fetchPageImpl, extract, notify = notifyAllUsers, now = new Date() }) {
  const res = await fetchImpl(page.url, {
    redirect: "follow",
    headers: { "User-Agent": "Mozilla/5.0 (compatible; OpportunityTracker/1.0)" },
  });
  if (!res.ok) return `fetch failed (${res.status})`;
  const text = mainText(await res.text());
  const contentHash = hashText(text);

  const stateRef = db.collection(STATE_COLLECTION).doc(page.key);
  const state = (await stateRef.get()).data() || {};
  const Timestamp = admin.firestore.Timestamp;
  if (state.contentHash === contentHash) {
    await stateRef.set({ lastCheckedAt: Timestamp.fromDate(now) }, { merge: true });
    return "unchanged";
  }

  const extraction = await extract(buildExtractionPrompt(page, text, now));

  // One opportunity per page per deadline year — an extension within the
  // same round updates it instead of creating a duplicate.
  const deadlineYear = extraction?.deadline ? new Date(extraction.deadline).getUTCFullYear() : null;
  const externalId = deadlineYear ? `${page.key}:${deadlineYear}` : null;
  let existingDoc = null;
  if (externalId) {
    const snap = await db.collection("opportunities").where("externalId", "==", externalId).limit(1).get();
    existingDoc = snap.docs[0] || null;
  }

  const decision = decide(extraction, existingDoc?.data(), now);
  const roundName = typeof extraction?.roundName === "string" ? extraction.roundName.trim() : "";
  const title = roundName ? `${page.name} — ${roundName}` : page.name;
  const summary = typeof extraction?.summary === "string" ? extraction.summary : "";
  let result = decision.action;

  if (decision.action === "create") {
    const ts = Timestamp.fromDate(now);
    const ref = await db.collection("opportunities").add({
      title,
      description: summary,
      sourceUrl: page.url,
      sourceUrlVerified: true,
      sourceUrlVerifiedAt: ts,
      sourceUrlIsFallback: false,
      client: page.client,
      deadline: Timestamp.fromDate(decision.deadline),
      status: "discovered",
      fitScorePercent: 0,
      fitReasoning: "Watched call page — a programme the company tracks directly.",
      tags: ["watched-call", page.key],
      kind: page.kind,
      externalId,
      watched: true,
      // The watcher sends its own "new call open" push below; skip the
      // generic new-opportunity trigger (and its auto-scoring).
      suppressNotification: true,
      discoveredAt: ts,
      updatedAt: ts,
    });
    await notify({
      type: "watchedCallOpen",
      opportunityId: ref.id,
      opportunityTitle: title,
      deadline: decision.deadline.toISOString(),
    });
  } else if (decision.action === "extend") {
    await existingDoc.ref.update({
      deadline: Timestamp.fromDate(decision.deadline),
      deadlineRemindersSent: [],
      description: summary || existingDoc.data().description || "",
      updatedAt: Timestamp.fromDate(now),
    });
    await notify({
      type: "watchedCallExtended",
      opportunityId: existingDoc.id,
      opportunityTitle: existingDoc.data().title || title,
      deadline: decision.deadline.toISOString(),
    });
  }

  await stateRef.set(
    {
      url: page.url,
      contentHash,
      lastCheckedAt: Timestamp.fromDate(now),
      lastChangedAt: Timestamp.fromDate(now),
      lastExtraction: {
        isOpen: extraction?.isOpen === true,
        deadline: extraction?.deadline || null,
        roundName,
      },
    },
    { merge: true },
  );
  return result;
}

/** Checks every watched page; one page failing never stops the others. */
async function checkAllWatchedPages(deps) {
  const results = {};
  for (const page of WATCHED_CALL_PAGES) {
    try {
      results[page.key] = await checkPage(page, deps);
    } catch (e) {
      logger.error(`callPageWatcher: ${page.key} failed`, e);
      results[page.key] = "error";
    }
  }
  logger.info(`callPageWatcher: ${JSON.stringify(results)}`);
  return results;
}

module.exports = {
  WATCHED_CALL_PAGES,
  mainText,
  hashText,
  decide,
  checkPage,
  checkAllWatchedPages,
  buildExtractionPrompt,
  /** Builds the scheduled function; [extract] comes from index.js (Gemini). */
  makeScheduledCallPageWatch: (extract) =>
    onSchedule({ schedule: "every day 07:30", timeZone: "Africa/Nairobi" }, async () => {
      await checkAllWatchedPages({ db: admin.firestore(), extract });
    }),
};
