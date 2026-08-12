const logger = require("firebase-functions/logger");
const {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
} = require("./tenderSourceConnector");
const { GEMINI_MODEL, genAiClient, extractJson, buildCompanyProfile } = require("../lib/aiHelpers");
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

    const prompt = `You are a business development assistant for a software company with this profile:

${profile}

Using web search, find up to 8 currently open opportunities from ${targeting}${
      source.searchQuery ? `, specifically related to: ${source.searchQuery}` : ""
    }, that this company (source: "${source.name}") is realistically qualified to bid on.
For each one, estimate a fit score (0-100) for how well this company's stack and
experience match the opportunity, and briefly justify the score.

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
No commentary, no markdown fences.`;

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: prompt,
      config: { tools: [{ googleSearch: {} }] },
    });

    const text = response.text ?? "";
    let candidates;
    try {
      candidates = extractJson(text);
    } catch (e) {
      logger.error("ApiConnector(aiSearch): failed to parse model output", e, text);
      throw new Error("Model did not return parseable JSON");
    }
    if (!Array.isArray(candidates)) candidates = [];

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