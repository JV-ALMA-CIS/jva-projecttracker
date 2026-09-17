const admin = require("firebase-admin");

/**
 * TenderSourceConnector — the common interface every discovery-method
 * connector implements. `runTenderSourceSync` (see
 * functions/tenderSourceSync.js) never branches on discoveryMethod itself —
 * it looks the connector up in TENDER_CONNECTORS (connectors/index.js) by
 * `source.discoveryMethod` and calls `.sync(source, db)`. Adding a new
 * discovery method means adding one new connector class + one registry
 * line; this file and tenderSourceSync.js never change.
 *
 * This replaces Milestone 3.7's `DISCOVERY_ADAPTERS` plain-object registry
 * with a class hierarchy (per the brief), while keeping the exact same
 * `{candidatesFound, created, duplicatesSkipped}` return contract so
 * `runTenderSourceSync`'s run-bookending logic is unchanged from
 * `runDiscoverySource`.
 */
class TenderSourceConnector {
  /**
   * @param {object} source - the TenderSource document (with `id`), or a
   *   not-yet-saved draft when testing before creation
   * @returns {Promise<{message: string, sampleCount: number|null}>}
   *   Should NOT write any opportunities — a dry run only. Throw on
   *   failure; testTenderSourceConnection.js catches it and returns
   *   {ok: false, message} to the client rather than propagating.
   */
  // eslint-disable-next-line no-unused-vars
  async test(source) {
    throw new Error(
      `${this.constructor.name} does not implement test() — every concrete connector must override it.`,
    );
  }

  /**
   * @param {object} source - the TenderSource document (with `id`)
   * @param {FirebaseFirestore.Firestore} db
   * @returns {Promise<{candidatesFound: number, created: number, duplicatesSkipped: number}>}
   */
  // eslint-disable-next-line no-unused-vars
  async sync(source, db) {
    throw new Error(
      `${this.constructor.name} does not implement sync() — every concrete connector must override it.`,
    );
  }
}

/**
 * True when [url] is one of Gemini's Google Search grounding-tool citation
 * links (`https://vertexaisearch.cloud.google.com/grounding-api-redirect/...`)
 * rather than a real, independently resolvable source page — mirrors
 * `isGroundingRedirectStub` in lib/utils/external_url.dart, which the
 * Flutter client uses to block the exact same shape before ever launching a
 * URL. These are session-scoped citation redirects the model returns as its
 * "source" when `_syncAiSearch` (apiConnector.js) uses Google Search
 * grounding; they frequently error out for a user opening them fresh later.
 * Checked here too (not only client-side) so a bad AI-search sourceUrl is
 * never written to Firestore in the first place — every existing/future
 * viewer of the opportunity is protected, not just whoever has this build
 * of the client.
 */
function isGroundingRedirectStub(url) {
  if (typeof url !== "string") return false;
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  return (
    parsed.host.includes("vertexaisearch.cloud.google.com") &&
    parsed.pathname.includes("grounding-api-redirect")
  );
}

/**
 * Phrases that show up on "soft 404" pages — a server answering with a real
 * 2xx status for content that is actually a not-found/error page, common on
 * WordPress-hosted government/embassy sites and CDN-fronted domains that
 * redirect dead links to a friendly page rather than a bare 404 status.
 * Matched case-insensitively against the first slice of the response body.
 * Deliberately conservative (each phrase names the page itself, not just
 * the digits "404", to avoid false-flagging a real tender page that happens
 * to mention "404" in an address or reference number).
 */
const SOFT_404_PATTERNS = [
  /page (you (are|were) looking for|you requested) (could not be found|was not found|cannot be found|doesn't exist|does not exist)/i,
  /(sorry,? )?(this|that) page (could not be found|was not found|doesn't exist|does not exist|is no longer available)/i,
  /we (can(no|')t|couldn't|could not) find (the|that|this) page/i,
  /error 404[\s\-:]*(page )?not found/i,
  /404[\s\-:]*(page )?not found/i,
  /the requested (page|url) (was not found|could not be found|does not exist) on this server/i,
];

/**
 * Phrases that show up on "soft block" pages — a WAF/bot-protection layer
 * (common on government/embassy sites fronted by a CDN) answering a real
 * 2xx status for a page that actually denies the request, rather than a
 * genuine 403/503. Caught the same real case that motivated adding this:
 * `ke.usembassy.gov`'s WAF returning "We're sorry, this site is currently
 * experiencing technical difficulties... Exception: forbidden" with status
 * 200 for an automated fetch of an otherwise-real, human-verified-dead PDF
 * link — status-code-only checking couldn't catch it, and neither could
 * SOFT_404_PATTERNS, since none of those phrases are 404-shaped.
 */
const SOFT_BLOCK_PATTERNS = [
  /experiencing technical difficulties/i,
  /exception:\s*forbidden/i,
  /access (to this (page|resource) )?(is |has been )?denied/i,
  /you (don't|do not) have permission to access/i,
  /request (was )?blocked/i,
];

/** First N chars of the body are enough to catch these — avoids reading/scanning a large page in full. */
const SOFT_404_SCAN_CHARS = 20000;

function looksLikeSoft404(bodyText) {
  if (!bodyText) return false;
  const snippet = bodyText.slice(0, SOFT_404_SCAN_CHARS);
  return (
    SOFT_404_PATTERNS.some((pattern) => pattern.test(snippet)) ||
    SOFT_BLOCK_PATTERNS.some((pattern) => pattern.test(snippet))
  );
}

/**
 * Checks whether [url] actually resolves with a real HTTP request — run
 * from a Cloud Function (a real server environment, not a CORS-restricted
 * browser), so this can do what the client-side equivalent tried and
 * failed to do reliably. Tries HEAD first (cheap): a 4xx/5xx there is a
 * fast, confident "unreachable" with no need for a follow-up request. But
 * a HEAD response has no body to inspect, and some real domains answer a
 * dead link with a 2xx "soft 404" page rather than a real 404 status — so
 * any status-only "reachable" verdict (HEAD 2xx/3xx, or HEAD rejected/
 * erroring and falling back) is confirmed with one GET and a scan of its
 * body for common not-found phrasing before being trusted. Bounded by a
 * short timeout per request so one slow/hanging site can't stall an
 * entire sync run across many candidates.
 *
 * This exists specifically to catch AI-search discovery
 * (`ApiConnector._syncAiSearch`) fabricating a plausible-looking but
 * nonexistent tender URL — a failure mode a stricter prompt alone cannot
 * fully prevent. A `false` result does not delete the opportunity; see
 * [createOpportunitiesFromCandidates]'s `sourceUrlVerified` field, which
 * lets the client warn the user instead of presenting a fabricated link as
 * equally trustworthy as a real one.
 */
/**
 * Returns `{reachable, finalUrl}` rather than a bare boolean: both fetch
 * calls already follow redirects (`redirect: "follow"`) to resolve a working
 * URL, so `response.url` — the post-redirect destination the fetch actually
 * landed on — is captured and handed back rather than discarded. Callers use
 * `finalUrl` to store the canonical, already-resolved destination as
 * `sourceUrl` instead of the original (possibly redirect-chained) link the
 * AI/connector returned, so a user's "Open Tender" click lands directly on
 * the real page with no redirect hop left to make. `finalUrl` is `null`
 * whenever `reachable` is `false` (nothing was confirmed to resolve).
 */
async function checkUrlReachable(url, { timeoutMs = 5000 } = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const headRes = await fetch(url, {
      method: "HEAD",
      signal: controller.signal,
      redirect: "follow",
    });
    if (headRes.status >= 400 && headRes.status !== 405) {
      return { reachable: false, finalUrl: null };
    }
  } catch {
    // Fall through to a GET attempt — some servers reject HEAD outright
    // (connection reset) rather than answering with 405.
  } finally {
    clearTimeout(timeout);
  }

  // Either HEAD said "reachable" or it was inconclusive (405/error) — in
  // both cases a GET is needed next: to confirm reachability in the
  // inconclusive case, and to fetch a body to scan in the reachable case
  // (HEAD alone can never rule out a soft 404).
  const getController = new AbortController();
  const getTimeout = setTimeout(() => getController.abort(), timeoutMs);
  try {
    const getRes = await fetch(url, {
      method: "GET",
      signal: getController.signal,
      redirect: "follow",
    });
    if (getRes.status >= 400) return { reachable: false, finalUrl: null };
    let bodyText;
    try {
      bodyText = await getRes.text();
    } catch {
      // Body unreadable (e.g. binary content, stream error) — fall back to
      // trusting the status code alone rather than treating an unreadable
      // body as a failure.
      return { reachable: true, finalUrl: getRes.url || url };
    }
    if (looksLikeSoft404(bodyText)) return { reachable: false, finalUrl: null };
    return { reachable: true, finalUrl: getRes.url || url };
  } catch {
    return { reachable: false, finalUrl: null };
  } finally {
    clearTimeout(getTimeout);
  }
}

/**
 * Shared candidate -> Opportunity write path used by every connector.
 * Centralizing this means dedup semantics (sourceUrl equality against the
 * `opportunities` collection — same rule Milestone 3.7 used) and the
 * Opportunity field shape stay identical across all discovery methods,
 * instead of each connector re-implementing its own write loop.
 *
 * Each candidate must have at least {title, sourceUrl}; other fields are
 * optional and defaulted. `deadline`, if present, must be an ISO 8601
 * string or omitted/null. A candidate whose sourceUrl is a Gemini
 * grounding-redirect stub (see [isGroundingRedirectStub]) is silently
 * dropped rather than written — same as a missing title/sourceUrl — since a
 * dead link is worse than no opportunity at all for that candidate.
 *
 * Every surviving candidate's `sourceUrl` is checked with a real HTTP
 * request (see [checkUrlReachable]) before writing, and the result is
 * stored as `sourceUrlVerified` — the opportunity is still created either
 * way (a reachability check has false negatives, e.g. a real site that
 * blocks automated requests, so a failed check must never silently discard
 * an otherwise-good opportunity the way the grounding-stub check does).
 * The client uses `sourceUrlVerified` to show a warning + manual
 * "mark as verified" override rather than presenting every link as equally
 * trustworthy.
 *
 * `reachabilityCheck` defaults to the real [checkUrlReachable] — overridable
 * purely so tests can stub it out instead of making real network calls; no
 * production caller ever needs to pass this.
 */
async function createOpportunitiesFromCandidates(
  db,
  source,
  candidates,
  { reachabilityCheck = checkUrlReachable } = {},
) {
  let created = 0;
  let duplicatesSkipped = 0;
  // Reachability breakdown across every candidate actually written this
  // call — surfaced in the return value (and logged by callers, see
  // ApiConnector._syncAiSearch / runOpportunityDiscovery) so it's visible
  // how much of the write-time protection (checkUrlReachable) is actually
  // catching, alongside the grounding/relevance drop counts logged upstream
  // of this function. A `sourceUrlIsFallback` write always counts toward
  // `unverifiedCount`, never `verifiedCount` — see the per-candidate
  // handling below.
  let verifiedCount = 0;
  let unverifiedCount = 0;

  for (const c of candidates) {
    if (!c || !c.sourceUrl || !c.title) continue;
    if (isGroundingRedirectStub(c.sourceUrl)) continue;

    const existing = await db
      .collection("opportunities")
      .where("sourceUrl", "==", c.sourceUrl)
      .limit(1)
      .get();
    if (!existing.empty) {
      duplicatesSkipped += 1;
      continue;
    }

    const now = admin.firestore.Timestamp.now();
    let deadline = null;
    if (c.deadline) {
      const parsed = new Date(c.deadline);
      if (!Number.isNaN(parsed.getTime())) {
        deadline = admin.firestore.Timestamp.fromDate(parsed);
      }
    }

    // A `sourceUrlIsFallback` candidate (ApiConnector._syncAiSearch's
    // TenderSource.website fallback for a candidate the grounding
    // cross-check rejected) points at the source's own homepage, not a
    // tender-specific page confirmed reachable this run — skip the HTTP
    // round-trip entirely (the source's website was presumably reachable
    // when the TenderSource was configured, and re-checking it on every
    // candidate that falls back to it would be redundant) and always store
    // it as unverified: it's a "go look here" fallback, not a confirmed
    // direct link, so the UI's unverified-link warning is the correct,
    // honest signal for it.
    let sourceUrl;
    let sourceUrlVerified;
    if (c.sourceUrlIsFallback) {
      sourceUrl = c.sourceUrl;
      sourceUrlVerified = false;
    } else {
      const reachability = await reachabilityCheck(c.sourceUrl);
      sourceUrlVerified = reachability.reachable;
      sourceUrl =
        reachability.reachable && reachability.finalUrl
          ? reachability.finalUrl
          : c.sourceUrl;
    }

    if (sourceUrlVerified) {
      verifiedCount += 1;
    } else {
      unverifiedCount += 1;
    }

    await db.collection("opportunities").add({
      title: c.title,
      description: c.description || "",
      sourceUrl,
      sourceUrlVerified,
      sourceUrlVerifiedAt: sourceUrlVerified ? now : null,
      // True only for a candidate ApiConnector._syncAiSearch rewrote to
      // source.website after the grounding cross-check rejected its
      // original (unconfirmed/fabricated-risk) sourceUrl — lets the UI show
      // a distinct "fallback" badge rather than presenting it identically
      // to a plain unverified direct link. Never true for any other write
      // path (restJson, runOpportunityDiscovery, manual import).
      sourceUrlIsFallback: c.sourceUrlIsFallback === true,
      client: c.client || null,
      deadline,
      status: "discovered",
      fitScorePercent: Math.max(
        0,
        Math.min(100, Math.round(c.fitScorePercent || 0)),
      ),
      fitReasoning: c.fitReasoning || "",
      tags: Array.isArray(c.tags) ? c.tags : [],
      // Set by ApiConnector._syncAiSearch (Kenya ranks above the other four
      // East African countries — see opportunityRelevance.js). Left
      // undefined/absent for any other write path (restJson, manual
      // import) that doesn't compute one — same "null means not yet
      // classified" convention runOpportunityDiscovery's equivalent field
      // already uses.
      ...(c.geographyPriority ? { geographyPriority: c.geographyPriority } : {}),
      discoveredAt: now,
      updatedAt: now,
      // Legacy fields kept for any code still reading discoverySource* —
      // intentionally left null here since this write path only ever runs
      // from a TenderSource, never a legacy DiscoverySource.
      discoverySourceId: null,
      discoverySourceType: null,
      tenderSourceId: source.id,
      tenderSourceCategory: source.category,
      tenderDiscoveryMethod: source.discoveryMethod,
    });
    created += 1;
  }

  return {
    candidatesFound: candidates.length,
    created,
    duplicatesSkipped,
    verifiedCount,
    unverifiedCount,
  };
}

module.exports = {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
  isGroundingRedirectStub,
  checkUrlReachable,
};