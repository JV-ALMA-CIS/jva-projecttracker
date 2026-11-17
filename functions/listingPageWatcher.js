const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const { mainText } = require("./callPageWatcher");
const { fetchPageImpl } = require("./lib/fetchPage");

/**
 * Watches pages that LIST tenders (e.g. the U.S. Embassy Nairobi
 * "Commercial Opportunities" page, where RFQs such as the Rosslyn compound
 * works are posted) and turns each new, still-open post into an
 * opportunity. AI web search rarely surfaces these posts; reading the
 * listing page directly is reliable.
 *
 * Daily: collect post links from each listing page; every link not seen
 * before is opened once, the AI reads its deadline / reference / whether
 * it's still open, and open ones are saved. Saved tenders arrive unscored,
 * so onOpportunityCreated runs Match Analysis on them and pushes the
 * qualifying (>= 70%) ones to everyone. Every link is remembered in
 * `watchedListingItems`, so a post is only ever read once.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

/** Listing pages to watch. Add an entry to watch another tender list. */
const WATCHED_LISTING_PAGES = [
  {
    key: "us-embassy-kenya",
    url: "https://ke.usembassy.gov/tag/commercial-opportunities/",
    // Post links look like /request-for-quotation-..., /subject-request-for-quotation-..., /solicitation-...
    linkPattern: /^https:\/\/ke\.usembassy\.gov\/[a-z0-9-]*(request-for-quotation|rfq|request-for-proposal|rfp|solicitation|invitation-for-bid|tender)[a-z0-9-]*\/?$/i,
    client: "U.S. Embassy Nairobi",
    tenderSourceCategory: "governmentAgency",
  },
];

const ITEMS_COLLECTION = "watchedListingItems";
const MAX_NEW_POSTS_PER_RUN = 15;
const BROWSER_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

/** Unique absolute post links on [html] matching [pattern], in page order. */
function extractPostLinks(html, pattern) {
  const links = [];
  for (const m of String(html).matchAll(/href="([^"#?]+)"/gi)) {
    const href = m[1];
    if (pattern.test(href) && !links.includes(href)) links.push(href);
  }
  return links;
}

/**
 * The post's own title. Sites usually put the site name in <h1> and the
 * post title in og:title / <title> ("POST TITLE - Site Name"), so those
 * come first with the trailing " - Site Name" removed. ALL-CAPS titles are
 * converted to readable title case (reference codes with digits are kept).
 */
function postTitle(html) {
  const clean = (s) =>
    String(s || "")
      .replace(/<[^>]+>/g, " ")
      .replace(/&#8211;|&ndash;/g, "-")
      .replace(/&#8217;|&rsquo;/g, "'")
      .replace(/&amp;/g, "&")
      .replace(/&[a-z#0-9]+;/gi, " ")
      .replace(/\s+/g, " ")
      .trim();
  const siteName = clean((String(html).match(/<meta[^>]+property="og:site_name"[^>]+content="([^"]+)"/i) || [])[1]);
  const h1 = clean((String(html).match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || [])[1]);
  // Only ever strip a trailing " - <site name>" — never a real part of the
  // title such as " - Rosslyn Ridge". The site name comes from og:site_name,
  // or from <h1> when the site puts its own name there.
  const known = [siteName, h1].filter((n) => n && n.length >= 3);
  const stripSite = (t) => {
    for (const name of known) {
      const re = new RegExp(`\\s+[-|–]\\s+${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i");
      if (re.test(t)) return t.replace(re, "");
    }
    return t;
  };
  const og = clean((String(html).match(/<meta[^>]+property="og:title"[^>]+content="([^"]+)"/i) || [])[1]);
  const docTitle = clean((String(html).match(/<title[^>]*>([^<]*)/i) || [])[1]);
  const candidate = og || docTitle;
  const title = candidate && !known.includes(candidate) ? stripSite(candidate) : h1;
  return toReadableCase(title);
}

/** "UNDERGROUND TANK CLEANING - ROSSLYN" -> "Underground Tank Cleaning - Rosslyn"; mixed case untouched. */
function toReadableCase(title) {
  if (!title || title !== title.toUpperCase() || !/[A-Z]{4,}/.test(title)) return title;
  const small = new Set(["a", "an", "and", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"]);
  return title
    .toLowerCase()
    .split(" ")
    .map((w, i) => {
      if (/\d/.test(w)) return w.toUpperCase(); // reference numbers like 19KE5026Q0128
      if (/^\W*(rfq|rfp|ifb|usg|cctv|nvr|cdc|jttf|ict|it|hvac|ups)\W*$/i.test(w)) return w.toUpperCase();
      if (i > 0 && small.has(w)) return w;
      return w.charAt(0).toUpperCase() + w.slice(1);
    })
    .join(" ");
}

function itemId(url) {
  return crypto.createHash("sha1").update(url).digest("hex");
}

function buildPostPrompt(title, text, now) {
  return `Today is ${now.toISOString().slice(0, 10)}. Below is a procurement
notice titled "${title}". Read it and report:

"""
${text.slice(0, 12000)}
"""

Return ONLY a JSON object:
{
  "isOpen": boolean (true only if submissions are still accepted today),
  "deadline": string | null (ISO 8601 date-time of the submission deadline, or null),
  "reference": string | null (RFQ / solicitation / tender reference number),
  "summary": string (2-3 sentences: what is required, where, and how to respond)
}
No commentary, no markdown fences.`;
}

/**
 * Processes one listing page. Dependencies injected for tests: [db],
 * [fetchImpl], [extract] (async prompt -> parsed JSON), [now].
 * Returns `{ links, skipped, created, closed, failed }`.
 */
async function checkListingPage(page, { db, fetchImpl = fetchPageImpl, extract, now = new Date() }) {
  const Timestamp = admin.firestore.Timestamp;
  const res = await fetchImpl(page.url, { redirect: "follow", headers: { "User-Agent": BROWSER_UA } });
  if (!res.ok) throw new Error(`listing fetch failed (${res.status})`);
  const links = extractPostLinks(await res.text(), page.linkPattern);

  const counts = { links: links.length, skipped: 0, created: 0, closed: 0, failed: 0 };
  let processedThisRun = 0;

  for (const url of links) {
    const itemRef = db.collection(ITEMS_COLLECTION).doc(itemId(url));
    if ((await itemRef.get()).exists) {
      counts.skipped += 1;
      continue;
    }
    if (processedThisRun >= MAX_NEW_POSTS_PER_RUN) break;
    processedThisRun += 1;

    // Already saved by another path (e.g. AI search)? Just remember it.
    const dup = await db.collection("opportunities").where("sourceUrl", "==", url).limit(1).get();
    if (!dup.empty) {
      await itemRef.set({ url, listingKey: page.key, result: "duplicate", processedAt: Timestamp.fromDate(now) });
      counts.skipped += 1;
      continue;
    }

    let title = "";
    let extraction;
    try {
      const postRes = await fetchImpl(url, { redirect: "follow", headers: { "User-Agent": BROWSER_UA } });
      if (!postRes.ok) throw new Error(`post fetch failed (${postRes.status})`);
      const html = await postRes.text();
      title = postTitle(html);
      extraction = await extract(buildPostPrompt(title, mainText(html), now));
    } catch (e) {
      // Not remembered — retried on the next run.
      logger.warn(`listingPageWatcher: ${url} failed: ${e.message}`);
      counts.failed += 1;
      continue;
    }

    const deadline = extraction?.deadline ? new Date(extraction.deadline) : null;
    const validDeadline = deadline && !Number.isNaN(deadline.getTime()) ? deadline : null;
    const open = extraction?.isOpen === true && (!validDeadline || validDeadline > now);

    if (open && title) {
      const ts = Timestamp.fromDate(now);
      const reference = typeof extraction.reference === "string" && extraction.reference.trim() ? extraction.reference.trim() : null;
      await db.collection("opportunities").add({
        title,
        description: typeof extraction.summary === "string" ? extraction.summary : "",
        sourceUrl: url,
        sourceUrlVerified: true,
        sourceUrlVerifiedAt: ts,
        sourceUrlIsFallback: false,
        client: page.client,
        procuringOrganization: page.client,
        tenderReferenceNumber: reference,
        deadline: validDeadline ? Timestamp.fromDate(validDeadline) : null,
        status: "discovered",
        // Unscored on purpose: onOpportunityCreated runs Match Analysis and
        // pushes if the score is >= 70.
        fitScorePercent: 0,
        fitReasoning: "",
        tags: ["watched-listing", page.key],
        kind: "tender",
        tenderSourceCategory: page.tenderSourceCategory || null,
        geographyPriority: "kenya",
        externalId: `${page.key}:${itemId(url)}`,
        discoveredAt: ts,
        updatedAt: ts,
      });
      counts.created += 1;
    } else {
      counts.closed += 1;
    }
    await itemRef.set({
      url,
      listingKey: page.key,
      title,
      result: open ? "created" : "closed",
      deadline: validDeadline ? Timestamp.fromDate(validDeadline) : null,
      processedAt: Timestamp.fromDate(now),
    });
  }
  return counts;
}

async function checkAllListingPages(deps) {
  const results = {};
  for (const page of WATCHED_LISTING_PAGES) {
    try {
      results[page.key] = await checkListingPage(page, deps);
    } catch (e) {
      logger.error(`listingPageWatcher: ${page.key} failed`, e);
      results[page.key] = { error: e.message };
    }
  }
  logger.info(`listingPageWatcher: ${JSON.stringify(results)}`);
  return results;
}

module.exports = {
  WATCHED_LISTING_PAGES,
  extractPostLinks,
  postTitle,
  toReadableCase,
  checkListingPage,
  checkAllListingPages,
  makeScheduledListingPageWatch: (extract) =>
    onSchedule({ schedule: "every day 07:15", timeZone: "Africa/Nairobi", timeoutSeconds: 300 }, async () => {
      await checkAllListingPages({ db: admin.firestore(), extract });
    }),
};
