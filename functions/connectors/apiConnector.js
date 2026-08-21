const logger = require("firebase-functions/logger");
const {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
} = require("./tenderSourceConnector");
const {
  GEMINI_MODEL,
  genAiClient,
  extractJson,
  buildCompanyProfile,
  isQuotaError,
  withQuotaRetry,
} = require("../lib/aiHelpers");
const { resolveSecret } = require("../lib/secrets");

/** Category -> prompt-targeting phrase, used only in `connectorConfig.mode === "aiSearch"`. */
const CATEGORY_TARGETING = {
  governmentAgency: "government procurement portals and public tenders",
  countyGovernment: "county/local government procurement notices",
  developmentPartner:
    "development organization funding/procurement opportunities (e.g. World Bank, USAID, bilateral donors)",
  unAgency: "United Nations agency procurement notices (UNGM, UNDP, UNICEF, etc.)",
  ngo: "NGO and non-profit sector opportunities and partnerships",
  privateSector: "private sector tenders and RFPs",
  customEnterprise: "the organization's own tenders and RFPs",
};

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

function safeHostname(url) {
  if (typeof url !== "string") return null;
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return null;
  }
}

/**
 * Returns the set of real pages Gemini's Google Search grounding tool
 * actually retrieved for this response — i.e. what the model genuinely saw,
 * as opposed to what it wrote in its free-text answer — keyed by URL with
 * the trailing slash normalized away, by resolving every grounding-chunk
 * redirect once. This is what candidates' `sourceUrl` values get
 * matched/replaced against in `_syncAiSearch`, so a candidate whose path was
 * invented by the model (right domain, wrong page) is caught even though a
 * domain-only check would miss it.
 *
 * ASSUMPTION FLAGGED FOR REVIEW: this reads
 * `response.candidates[0].groundingMetadata.groundingChunks[].web.uri`,
 * the standard Gemini API shape when using the `googleSearch` tool
 * (config.tools in `_syncAiSearch` below). `genAiClient()` (lib/aiHelpers.js)
 * wasn't available to confirm it passes the raw SDK response through
 * unchanged rather than reshaping it — worth a quick check against that
 * file, or just a console.log of one real `response` object, before
 * relying on this in production. If the shape doesn't match, `available`
 * below will always be false and the cross-check will silently skip
 * (logged as a warning) rather than break anything.
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
 * Builds request headers for a `restJson` source. `authConfig` on the
 * TenderSource document only ever holds `{authType, headerName, secretName}`
 * — the raw credential itself lives in Secret Manager and is resolved here,
 * in memory, for the duration of one request. It is never written back to
 * Firestore. Matches the NuaSense proxy's existing convention.
 */
async function resolveAuthHeaders(source) {
  const { headerName, secretName } = source.authConfig || {};
  if (!headerName || !secretName) return { Accept: "application/json" };
  const secretValue = await resolveSecret(secretName);
  return { Accept: "application/json", [headerName]: secretValue };
}

/**
 * ApiConnector handles `discoveryMethod: "api"` sources in one of two
 * modes, chosen by `source.connectorConfig.mode`:
 *
 *  - "aiSearch" (default) — Gemini + Google Search grounded discovery,
 *    identical technique to Milestone 3.7's `runAiWebSearchAdapter`. This
 *    preserves the existing behavior for the categories that don't have a
 *    literal procurement API to call.
 *  - "restJson" — a literal `fetch()` against `connectorConfig.endpointUrl`,
 *    expecting a JSON array response, mapped into candidates via
 *    `connectorConfig.fieldMap` (e.g. {title: "tenderTitle", sourceUrl: "url",
 *    description: "desc", deadline: "closingDate"}). Use this once a real
 *    procurement API integration is available for a source.
 */
class ApiConnector extends TenderSourceConnector {
  async sync(source, db) {
    const mode = source.connectorConfig?.mode || "aiSearch";
    if (mode === "restJson") return this._syncRestJson(source, db);
    return this._syncAiSearch(source, db);
  }

  /**
   * Dry run — no opportunities are written. aiSearch mode only validates
   * config shape (a real Gemini+Search call costs money, so "test" doesn't
   * make one). restJson mode makes one real request and reports how many
   * items it would have mapped into candidates.
   */
  async test(source) {
    const mode = source.connectorConfig?.mode || "aiSearch";
    if (mode === "aiSearch") {
      return {
        message:
          "AI-search sources can't be dry-run without cost — save and use \"Run now\" to test for real.",
        sampleCount: null,
      };
    }

    const endpointUrl = source.connectorConfig?.endpointUrl;
    if (!endpointUrl) {
      throw new Error("connectorConfig.endpointUrl is required for restJson mode");
    }
    const headers = await resolveAuthHeaders(source);
    const res = await fetch(endpointUrl, { headers });
    if (!res.ok) {
      throw new Error(`API request failed: ${res.status} ${res.statusText}`);
    }
    const body = await res.json();
    const resultsPath = source.connectorConfig?.resultsPath;
    const items = Array.isArray(body)
      ? body
      : Array.isArray(body?.[resultsPath])
        ? body[resultsPath]
        : [];
    return {
      message: `Connected successfully — found ${items.length} item(s).`,
      sampleCount: items.length,
    };
  }

  async _syncAiSearch(source, db) {
    const profile = await buildCompanyProfile();
    const ai = genAiClient();
    const targeting =
      CATEGORY_TARGETING[source.category] || "open business opportunities";

    const siteInstruction = source.website
      ? `\n\nThis source's own tender/opportunity listing page is: ${source.website}
Use "site:${safeHostname(source.website) || source.website}" style web searches
first and prioritize opportunities you can find published ON that page or
elsewhere on that same domain — that domain is the authoritative listing for
this source. Only look beyond that domain if it does not list enough current
opportunities on its own.`
      : "";

    const prompt = `You are a business development assistant for a software company with this profile:

${profile}

Using web search, find up to 8 currently open opportunities from ${targeting}${
      source.searchQuery ? `, specifically related to: ${source.searchQuery}` : ""
    }, that this company (source: "${source.name}") is realistically qualified to bid on.${siteInstruction}
For each one, estimate a fit score (0-100) for how well this company's stack and
experience match the opportunity, and briefly justify the score.

CRITICAL — "sourceUrl" must be a direct, real, publicly loadable link to the
actual tender/opportunity page as it appears in the address bar of the site
that published it (e.g. the procurement portal, UN/NGO tender board, or
donor's own site) — the exact URL a person could paste into a browser and
land on that tender. Copy this URL EXACTLY as it appears in your search
results/grounding data — character for character. NEVER type out, guess,
reconstruct, or paraphrase a URL from a page's title even if you are
confident you know its slug or numbering scheme; if you did not literally
see the URL in your search results, you do not have it. NEVER return a
Google Search redirect/citation link (any URL on a
"vertexaisearch.cloud.google.com" or similar Google-hosted redirect domain)
— those are internal citation artifacts, not something a person can open
later, and are worthless here. If you cannot determine the real, direct URL
for an opportunity, omit that opportunity entirely rather than guessing or
substituting a search-result link.

Return ONLY a JSON array, each item shaped as:
{
  "title": string,
  "description": string,
  "sourceUrl": string,
  "client": string | null,
  "deadline": string | null (ISO 8601 date, or null if unknown),
  "tags": string[],
  "fitScorePercent": number (0-100),
  "fitReasoning": string
}
If none of the opportunities you found have a real, verifiable sourceUrl,
return an empty JSON array: []
Return ONLY the JSON array — no commentary, no markdown fences, no
explanation before or after it, even when the array is empty.`;

    let response;
    try {
      response = await withQuotaRetry(() =>
        ai.models.generateContent({
          model: GEMINI_MODEL,
          contents: prompt,
          config: { tools: [{ googleSearch: {} }] },
        }),
      );
    } catch (e) {
      if (isQuotaError(e)) {
        throw new Error(
          "Vertex AI Gemini quota exceeded for this project — too many AI-search syncs ran in a short window. Wait a few minutes and try again, or raise the Gemini quota in Google Cloud Console.",
        );
      }
      throw e;
    }

    const text = response.text ?? "";
    let candidates;
    try {
      candidates = extractJson(text);
    } catch (e) {
      // The stricter "never guess a URL, omit the opportunity instead"
      // instruction above means the model legitimately has nothing to
      // report more often than before — it sometimes explains that in
      // prose ("no verifiable opportunities found...") instead of
      // returning `[]`, which extractJson treats as a parse failure.
      // Since an empty result is an expected, non-error outcome here
      // (unlike other extractJson call sites, where "no JSON" really is
      // a broken response), log it for visibility and continue with zero
      // candidates rather than failing the whole sync.
      logger.warn(
        "ApiConnector(aiSearch): model returned no parseable JSON — treating as zero candidates",
        e,
        text,
      );
      candidates = [];
    }
    if (!Array.isArray(candidates)) candidates = [];

    // Replace each candidate's sourceUrl with the actual grounded URL Google
    // Search retrieved, matched path-for-path (not just by domain) — this is
    // what catches a candidate where Gemini typed out a plausible-looking
    // but invented path on an otherwise-real domain (e.g.
    // "ke.usembassy.gov/embassy-of-the-united-states..." when the real,
    // grounded page was "ke.usembassy.gov/request-for-quotation-..."). A
    // domain-only check would have let that through; exact-URL matching
    // does not. Falls back to domain-only matching (dropping, not
    // rewriting) only when no exact grounded URL match exists, so a
    // candidate is never silently kept with a fabricated path.
    const { available: groundingAvailable, urls: groundedUrls } =
      await extractGroundedUrls(response);
    if (!groundingAvailable) {
      // Genuinely no grounding metadata on this response at all (or an SDK
      // shape mismatch) — the cross-check cannot run, so fall back to
      // trusting the model's candidates as-is, same as before this fix
      // existed.
      logger.warn(
        "ApiConnector(aiSearch): no grounding metadata on this response — skipping the grounded-URL cross-check for this run",
      );
    } else {
      // Grounding metadata WAS present — Gemini did search real pages —
      // even if `groundedUrls` ends up empty because every citation
      // redirect failed to resolve. That is NOT the same as "no grounding"
      // and must fail closed (drop unmatched candidates) rather than let
      // every candidate through unfiltered, which is what let fabricated
      // URLs reach production even with this check nominally in place.
      const beforeCount = candidates.length;
      candidates = candidates
        .map((c) => {
          const normalized =
            typeof c?.sourceUrl === "string"
              ? c.sourceUrl.replace(/\/$/, "")
              : null;
          const groundedMatch =
            normalized != null ? groundedUrls.get(normalized) : null;
          return groundedMatch ? { ...c, sourceUrl: groundedMatch } : null;
        })
        .filter((c) => c != null);
      const droppedCount = beforeCount - candidates.length;
      if (droppedCount > 0) {
        logger.info(
          `ApiConnector(aiSearch): dropped ${droppedCount} candidate(s) whose sourceUrl wasn't backed by an exact search-grounding match`,
        );
      }
    }

    return createOpportunitiesFromCandidates(db, source, candidates);
  }

  async _syncRestJson(source, db) {
    const endpointUrl = source.connectorConfig?.endpointUrl;
    if (!endpointUrl) {
      throw new Error("connectorConfig.endpointUrl is required for restJson mode");
    }
    const fieldMap = source.connectorConfig?.fieldMap || {};
    const headers = await resolveAuthHeaders(source);

    const res = await fetch(endpointUrl, { headers });
    if (!res.ok) {
      throw new Error(`API request failed: ${res.status} ${res.statusText}`);
    }
    const body = await res.json();
    const items = Array.isArray(body)
      ? body
      : Array.isArray(body?.[source.connectorConfig?.resultsPath])
        ? body[source.connectorConfig.resultsPath]
        : [];

    const candidates = items.map((item) => ({
      title: item[fieldMap.title || "title"],
      description: item[fieldMap.description || "description"] || "",
      sourceUrl: item[fieldMap.sourceUrl || "url"],
      client: item[fieldMap.client || "client"] || null,
      deadline: item[fieldMap.deadline || "deadline"] || null,
      tags: Array.isArray(item[fieldMap.tags]) ? item[fieldMap.tags] : [],
      fitScorePercent: 0,
      fitReasoning: "",
    }));

    return createOpportunitiesFromCandidates(db, source, candidates);
  }
}

module.exports = { ApiConnector };