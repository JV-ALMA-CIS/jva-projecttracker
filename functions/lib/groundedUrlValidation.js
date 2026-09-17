const logger = require("firebase-functions/logger");

/**
 * Resolves one Gemini grounding-chunk redirect URI to the real, final URL it
 * points to — this is the actual page Google Search grounding retrieved.
 * Used to validate candidates path-for-path: a candidate whose sourceUrl
 * merely shares a hostname with a grounded citation (e.g. the right domain
 * but a model-invented path) is exactly the failure mode a domain-only
 * check would miss. Any failure (timeout, non-2xx, DNS issue) just means
 * this one citation doesn't contribute a URL — never thrown, since one bad
 * citation must not abort the whole cross-check.
 */
async function resolveGroundingUrl(redirectUri, { timeoutMs = 5000 } = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(redirectUri, {
      method: "HEAD",
      redirect: "follow",
      signal: controller.signal,
    });
    // A HEAD 4xx/5xx (or one silently rejected, i.e. no final `res.url`)
    // doesn't necessarily mean the redirect is dead — plenty of real sites
    // (WordPress/government sites among them) reject HEAD outright while
    // answering GET normally. Falling through to a GET attempt here
    // mirrors the same HEAD-then-GET pattern `checkUrlReachable`
    // (tenderSourceConnector.js) already uses, and matters a lot here:
    // this function silently failing to resolve real citations is what
    // let fabricated candidate URLs slip through the exact-match check
    // undetected in production.
    if (res.url && res.status < 400) return res.url;
  } catch {
    // Fall through to GET.
  } finally {
    clearTimeout(timeout);
  }

  const getController = new AbortController();
  const getTimeout = setTimeout(() => getController.abort(), timeoutMs);
  try {
    const res = await fetch(redirectUri, {
      method: "GET",
      redirect: "follow",
      signal: getController.signal,
    });
    // Status must be checked here too, same as the HEAD attempt above —
    // a citation redirect can legitimately resolve (no network error, a
    // real res.url) to a page that is itself dead (e.g. Google's grounding
    // tool citing a stale link that now 404s on the source's own site, the
    // real cause of a "sam.gov/404" sourceUrl reaching production: the
    // redirect resolved cleanly, so its status was never checked, and the
    // dead page's own URL was trusted as a verified match). Returning it
    // unconditionally here defeats the entire point of exact-URL grounding
    // validation — an unreachable resolved URL must not be treated as
    // confirmation of anything.
    if (res.url && res.status < 400) return res.url;
    return null;
  } catch {
    return null;
  } finally {
    clearTimeout(getTimeout);
  }
}

/**
 * Returns the set of real pages Gemini's Google Search grounding tool
 * actually retrieved for this response — i.e. what the model genuinely saw,
 * as opposed to what it wrote in its free-text answer — keyed by URL with
 * the trailing slash normalized away, by resolving every grounding-chunk
 * redirect once. This is what candidates' `sourceUrl` values get
 * matched/replaced against by [applyGroundedUrlCrossCheck], so a candidate
 * whose path was invented by the model (right domain, wrong page) is caught
 * even though a domain-only check would miss it.
 *
 * ASSUMPTION FLAGGED FOR REVIEW: this reads
 * `response.candidates[0].groundingMetadata.groundingChunks[].web.uri`,
 * the standard Gemini API shape when using the `googleSearch` tool. Worth a
 * quick check against a real `response` object before relying on this in a
 * new call site — if the shape doesn't match, `available` below will always
 * be false and the cross-check will silently skip (logged as a warning)
 * rather than break anything.
 *
 * Return shape distinguishes two very different "nothing to check against"
 * situations, which must NOT be handled the same way by the caller:
 *  - `{ available: false }` — no grounding metadata at all (missing
 *    groundingChunks, or a shape mismatch per the ASSUMPTION note above).
 *    The cross-check genuinely cannot run, so the caller skips it and
 *    trusts the model's candidates as-is — same as before this fix existed.
 *  - `{ available: true, urls: Map }` — grounding metadata WAS present
 *    (Gemini did search real pages), but `urls` may still be an empty Map
 *    if every citation redirect failed to resolve (e.g. every real site
 *    rejected both HEAD and GET, or a network blip). This is NOT the same
 *    as "no grounding" — the caller must fail closed here (drop every
 *    candidate) rather than let fabricated URLs through unfiltered, which
 *    is exactly the bug that let invented ke.usembassy.gov paths reach
 *    production even after the exact-match check was added: an empty Map
 *    was indistinguishable from "no grounding metadata" and both silently
 *    skipped the check.
 */
async function extractGroundedUrls(response) {
  const chunks = response?.candidates?.[0]?.groundingMetadata?.groundingChunks;
  if (!Array.isArray(chunks) || chunks.length === 0) {
    return { available: false, urls: null };
  }

  const redirectUris = chunks
    .map((chunk) => chunk?.web?.uri)
    .filter((uri) => typeof uri === "string");
  if (redirectUris.length === 0) {
    return { available: false, urls: null };
  }

  const resolved = await Promise.all(
    redirectUris.map((uri) => resolveGroundingUrl(uri)),
  );
  const urlByNormalized = new Map();
  for (const url of resolved) {
    if (!url) continue;
    urlByNormalized.set(url.replace(/\/$/, ""), url);
  }
  return { available: true, urls: urlByNormalized };
}

/**
 * Applies the fail-closed, exact-URL grounding cross-check to [candidates]:
 * for each candidate, its `sourceUrl` must exactly match (path-for-path, not
 * just domain) a URL Gemini's Google Search grounding tool actually
 * retrieved for [response] — see [extractGroundedUrls]'s doc comment for why
 * "available but empty" must fail closed rather than being treated as "no
 * grounding". A matching candidate has its `sourceUrl` rewritten to the
 * exact resolved grounded URL (catches trailing-slash/redirect differences);
 * a non-matching candidate is dropped, not rewritten to a domain-only guess.
 *
 * When no grounding metadata is available at all (`available: false`),
 * every candidate is returned as `kept` unchanged — the check genuinely
 * cannot run, so callers fall back to trusting the model's candidates as
 * before this protection existed, same posture the two existing call sites
 * always had. `dropped` is always `[]` in that case (nothing was rejected;
 * the check didn't run).
 *
 * Returns `{kept, dropped}` rather than just the surviving array so a caller
 * that wants to do something useful with a rejected candidate (e.g.
 * `ApiConnector._syncAiSearch`'s `TenderSource.website` fallback) can, without
 * re-deriving which candidates were dropped and why.
 *
 * [logPrefix] labels the dropped-count log line so it's clear which caller
 * (which AI-search code path) the drop happened in.
 */
async function applyGroundedUrlCrossCheck(candidates, response, { logPrefix } = {}) {
  const { available: groundingAvailable, urls: groundedUrls } =
    await extractGroundedUrls(response);

  if (!groundingAvailable) {
    logger.warn(
      `${logPrefix || "applyGroundedUrlCrossCheck"}: no grounding metadata on this response — skipping the grounded-URL cross-check for this run`,
    );
    return { kept: candidates, dropped: [], groundedUrls: [] };
  }

  const kept = [];
  const dropped = [];
  for (const c of candidates) {
    const normalized =
      typeof c?.sourceUrl === "string" ? c.sourceUrl.replace(/\/$/, "") : null;
    const groundedMatch = normalized != null ? groundedUrls.get(normalized) : null;
    if (groundedMatch) {
      kept.push({ ...c, sourceUrl: groundedMatch });
    } else {
      dropped.push(c);
    }
  }
  if (dropped.length > 0) {
    logger.info(
      `${logPrefix || "applyGroundedUrlCrossCheck"}: dropped ${dropped.length} candidate(s) whose sourceUrl wasn't backed by an exact search-grounding match`,
    );
  }
  // Every real page grounding actually retrieved this run (values of
  // groundedUrls, i.e. the same set kept candidates were matched against) —
  // handed back so a caller can look for a genuinely real, better-than-the-
  // bare-homepage fallback among them for a dropped candidate. This is never
  // a guess: it's exactly the set of URLs Google Search grounding confirmed
  // exist, just not ones any surviving candidate happened to claim.
  const groundedUrlList = groundingAvailable ? [...groundedUrls.values()] : [];
  return { kept, dropped, groundedUrls: groundedUrlList };
}

module.exports = {
  resolveGroundingUrl,
  extractGroundedUrls,
  applyGroundedUrlCrossCheck,
};
