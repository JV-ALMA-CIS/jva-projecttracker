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
const { applyGroundedUrlCrossCheck } = require("../lib/groundedUrlValidation");
const {
  isAllowedCountry,
  classifyGeographyPriority,
} = require("../opportunityRelevance");
const { resolveSecret } = require("../lib/secrets");

/**
 * How many grounding-cross-check-rejected candidates from one sync run may
 * fall back to `source.website` (see `_syncAiSearch`'s cross-check block).
 * Capped so a source whose grounding is broadly failing this run doesn't
 * flood the pipeline with several generic homepage-link opportunities —
 * one or two is a useful "at least point them somewhere real" fallback,
 * many is noise.
 */
const MAX_WEBSITE_FALLBACKS_PER_RUN = 3;

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

function safeHostname(url) {
  if (typeof url !== "string") return null;
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return null;
  }
}

/**
 * True when [url] is on the same registrable-ish domain as [website] (via
 * [safeHostname], which already strips a leading "www."). Used only to find
 * a genuinely real, grounding-confirmed page to prefer over the bare
 * homepage for a fallback — never to accept a candidate's own claimed URL
 * (that's applyGroundedUrlCrossCheck's exact-match job, not this).
 */
function sameDomain(url, website) {
  const a = safeHostname(url);
  const b = safeHostname(website);
  return a != null && b != null && a === b;
}

/**
 * Picks a single better-than-the-homepage fallback URL from [groundedUrls]
 * (every real page Google Search grounding actually retrieved this run —
 * see applyGroundedUrlCrossCheck) when the pairing is unambiguous: exactly
 * one grounded URL lives on [source.website]'s domain, AND exactly one
 * candidate in [dropped] needs a fallback this run. With any more of
 * either — several same-domain grounded pages, or several dropped
 * candidates — there's no way to know which real page belongs to which
 * candidate, so this deliberately returns `null` rather than guess or
 * attach the same URL to more than one candidate (never mis-attribute a
 * real page to the wrong opportunity). Falls back to the bare
 * `source.website` homepage in every other case — never invents a URL.
 */
function pickUnambiguousGroundedFallback(dropped, groundedUrls, source) {
  if (!Array.isArray(dropped) || dropped.length !== 1) return null;
  const sameDomainMatches = (groundedUrls || []).filter((url) =>
    sameDomain(url, source.website),
  );
  return sameDomainMatches.length === 1 ? sameDomainMatches[0] : null;
}

/**
 * HARD geography gate — TenderSources are not all Kenya/East-Africa scoped
 * (CanadaBuys, UK Find a Tender, DevelopmentAid, etc. are seeded alongside
 * the regional ones — see seedTenderSources.js), so this connector needs
 * the same allow-list runOpportunityDiscovery applies: only Kenya/Uganda/
 * Tanzania/Rwanda/Burundi candidates survive, regardless of fit score.
 * Every survivor is tagged with `geographyPriority` (Kenya ranks above the
 * other four East African countries — see classifyGeographyPriority) so a
 * TenderSource-originated opportunity is prioritized identically to one
 * from the standalone AI-search "Search" button, regardless of which
 * discovery path found it. Pure/synchronous so it's independently testable
 * without stubbing Gemini or fetch.
 */
function applyGeographyGate(candidates) {
  return candidates
    .filter((c) => isAllowedCountry(c))
    .map((c) => ({ ...c, geographyPriority: classifyGeographyPriority(c) }));
}

/**
 * Turns a subset of grounding-cross-check-rejected candidates into
 * `sourceUrlIsFallback` candidates pointing at a real URL — the "at least
 * point them somewhere real" fallback for a source whose grounding
 * genuinely couldn't confirm an exact tender URL this run. Prefers an
 * unambiguous same-domain page grounding actually retrieved (see
 * [pickUnambiguousGroundedFallback]) over the bare `source.website`
 * homepage when one can be attributed with certainty; otherwise falls back
 * to the homepage, exactly as before — never invents or guesses a URL that
 * wasn't independently confirmed real by either the reachability check
 * (createOpportunitiesFromCandidates) or Google Search grounding itself.
 * Pure/synchronous so it's independently testable without stubbing Gemini
 * or fetch.
 *
 * Returns `[]` when `source.website` is unset (no fallback is ever invented
 * without a known real website) or when [dropped] is empty. Only candidates
 * with a real `title` are eligible (same "at least identify what it is" bar
 * `createOpportunitiesFromCandidates` already applies to every candidate),
 * capped at [MAX_WEBSITE_FALLBACKS_PER_RUN] so a source whose grounding is
 * broadly failing this run doesn't flood the pipeline with many generic
 * fallback opportunities.
 */
function buildWebsiteFallbackCandidates(dropped, source, groundedUrls = []) {
  if (!source?.website || !Array.isArray(dropped) || dropped.length === 0) {
    return [];
  }
  const eligible = dropped.filter((c) => c && c.title);
  const unambiguousFallback = pickUnambiguousGroundedFallback(
    eligible,
    groundedUrls,
    source,
  );
  return eligible
    .slice(0, MAX_WEBSITE_FALLBACKS_PER_RUN)
    .map((c) => ({
      ...c,
      sourceUrl: unambiguousFallback || source.website,
      sourceUrlIsFallback: true,
    }));
}

/**
 * Extra guard for a source with a known real `website`: even a candidate
 * that survived the exact-URL grounding cross-check (i.e. its sourceUrl
 * matched something Google Search grounding retrieved) is demoted to a
 * `sourceUrlIsFallback` candidate — same treatment as a grounding-rejected
 * one, pointing at `source.website` instead — if that sourceUrl is NOT on
 * the same domain as `source.website`. This exists specifically for the
 * case the plain exact-match check cannot catch on its own: when Google
 * Search grounding metadata is unavailable for a response at all
 * (`applyGroundedUrlCrossCheck` then trusts every candidate's claimed URL
 * unchecked — see its doc comment), a fabricated `ke.usembassy.gov` path
 * would otherwise sail through untouched as a "kept" candidate whenever the
 * model happens to also claim the right domain. A source that has a known
 * real website should never trust an unverifiable or off-domain URL as
 * primary — the website (or a same-domain grounded page, same as
 * [pickUnambiguousGroundedFallback]) is always safer than an unconfirmed
 * claim. No-op when `source.website` is unset — this guard only ever
 * applies to sources that have one.
 */
function enforceSameDomainWhenWebsiteKnown(kept, source, groundedUrls = []) {
  if (!source?.website || !Array.isArray(kept) || kept.length === 0) {
    return { kept, demoted: [] };
  }

  const stillKept = [];
  const demoted = [];
  for (const c of kept) {
    if (sameDomain(c.sourceUrl, source.website)) {
      stillKept.push(c);
    } else {
      demoted.push(c);
    }
  }
  if (demoted.length === 0) return { kept: stillKept, demoted: [] };

  const fallbacks = buildWebsiteFallbackCandidates(demoted, source, groundedUrls);
  return { kept: stillKept, demoted: fallbacks };
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

GEOGRAPHY — only include opportunities located in Kenya, Uganda, Tanzania,
Rwanda, or Burundi. Do not include opportunities from any other country
(e.g. Canada, the UK, the US, or elsewhere in Africa) even if they otherwise
look like a strong match — they will be discarded regardless of fit score,
so do not waste a slot on one.

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
    // does not. Candidates that fail the check are dropped (never rewritten
    // to a domain-only guess) by applyGroundedUrlCrossCheck (shared with
    // runOpportunityDiscovery in index.js — see lib/groundedUrlValidation.js).
    const candidatesFromModel = candidates.length;
    const { kept, dropped, groundedUrls } = await applyGroundedUrlCrossCheck(
      candidates,
      response,
      { logPrefix: "ApiConnector(aiSearch)" },
    );
    const groundingDroppedCount = dropped.length;

    // Extra guard on top of the exact-match check above, specifically for
    // when grounding metadata was unavailable this run (applyGroundedUrlCrossCheck
    // then trusts every candidate's claimed URL unchecked) — a source with a
    // known real website must never let an off-domain/unverifiable URL stand
    // as the primary sourceUrl. See enforceSameDomainWhenWebsiteKnown.
    const { kept: sameDomainKept, demoted: sameDomainDemoted } =
      enforceSameDomainWhenWebsiteKnown(kept, source, groundedUrls);
    candidates = sameDomainKept;
    if (sameDomainDemoted.length > 0) {
      logger.info(
        `ApiConnector(aiSearch): demoted ${sameDomainDemoted.length} off-domain candidate(s) to source.website fallback (${source.website})`,
      );
      candidates = [...candidates, ...sameDomainDemoted];
    }

    // A candidate dropped for lacking an exact grounded match never had a
    // real, confirmed sourceUrl to begin with — it's not "downgrading" a
    // good direct tender URL to fall back to a real page for a few of them,
    // since a fabricated 404 is strictly worse for the user than a working
    // link they can search from. See buildWebsiteFallbackCandidates for the
    // selection/cap logic, including when it can use a genuinely better,
    // grounding-confirmed same-domain page instead of the bare homepage.
    const fallbacks = buildWebsiteFallbackCandidates(dropped, source, groundedUrls);
    if (fallbacks.length > 0) {
      logger.info(
        `ApiConnector(aiSearch): falling back ${fallbacks.length} dropped candidate(s) to source.website (${source.website})`,
      );
      candidates = [...candidates, ...fallbacks];
    }

    // Applied after the website-fallback step above (not before) so a
    // fallback candidate is checked too — pointing at a source's website
    // never exempts it from the geography rule. See applyGeographyGate.
    const beforeGeographyCount = candidates.length;
    candidates = applyGeographyGate(candidates);
    const geographyDroppedCount = beforeGeographyCount - candidates.length;

    const result = await createOpportunitiesFromCandidates(db, source, candidates);
    // One summary line per sync showing where candidates were lost — same
    // "diagnosable from Cloud Logging alone" goal as runOpportunityDiscovery's
    // equivalent summary in index.js.
    logger.info(
      `ApiConnector(aiSearch): ${candidatesFromModel} from model -> ` +
        `${groundingDroppedCount} dropped (grounding), ` +
        `${sameDomainDemoted.length} demoted (off-domain), ` +
        `${fallbacks.length} fell back to source.website, ` +
        `${geographyDroppedCount} dropped (geography — outside Kenya/Uganda/Tanzania/Rwanda/Burundi), ` +
        `${result.duplicatesSkipped} duplicates skipped, ` +
        `${result.created} created (${result.verifiedCount} verified, ${result.unverifiedCount} unverified)`,
    );
    return result;
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

module.exports = {
  ApiConnector,
  buildWebsiteFallbackCandidates,
  pickUnambiguousGroundedFallback,
  enforceSameDomainWhenWebsiteKnown,
  applyGeographyGate,
};