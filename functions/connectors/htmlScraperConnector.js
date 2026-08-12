const cheerio = require("cheerio");
const {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
} = require("./tenderSourceConnector");

/**
 * HtmlScraperConnector handles `discoveryMethod: "htmlScraping"` sources.
 * Fetches `connectorConfig.pageUrl` and extracts one candidate per element
 * matching `connectorConfig.selectors.item`, using `cheerio` (add to
 * functions/package.json — see milestone report). All selectors are
 * per-source configuration, not code — this is what lets one connector
 * class serve every HTML-scraped source without a per-site connector.
 *
 * Expected `connectorConfig.selectors` shape:
 * {
 *   "item": ".tender-row",              // required — one per opportunity
 *   "title": ".tender-title",           // relative to item
 *   "sourceUrl": "a.tender-link@href",  // "selector@attr" reads an attribute
 *   "description": ".tender-summary",
 *   "deadline": ".tender-deadline"
 * }
 */
class HtmlScraperConnector extends TenderSourceConnector {
  async test(source) {
    const pageUrl = source.connectorConfig?.pageUrl;
    const selectors = source.connectorConfig?.selectors;
    if (!pageUrl || !selectors?.item) {
      throw new Error(
        "connectorConfig.pageUrl and connectorConfig.selectors.item are required",
      );
    }
    const res = await fetch(pageUrl);
    if (!res.ok) {
      throw new Error(`Page fetch failed: ${res.status} ${res.statusText}`);
    }
    const $ = cheerio.load(await res.text());
    const count = $(selectors.item).length;
    return {
      message:
        count > 0
          ? `Connected successfully — selector matched ${count} item(s).`
          : `Page fetched, but "${selectors.item}" matched 0 elements — check the selector.`,
      sampleCount: count,
    };
  }

  async sync(source, db) {
    const pageUrl = source.connectorConfig?.pageUrl;
    const selectors = source.connectorConfig?.selectors;
    if (!pageUrl || !selectors?.item) {
      throw new Error(
        "connectorConfig.pageUrl and connectorConfig.selectors.item are required for HTML scraping sources",
      );
    }

    const res = await fetch(pageUrl);
    if (!res.ok) {
      throw new Error(`Page fetch failed: ${res.status} ${res.statusText}`);
    }
    const html = await res.text();
    const $ = cheerio.load(html);

    const candidates = [];
    $(selectors.item).each((_, el) => {
      const $el = $(el);
      candidates.push({
        title: this._read($, $el, selectors.title),
        description: this._read($, $el, selectors.description) || "",
        sourceUrl: this._resolveUrl(
          pageUrl,
          this._read($, $el, selectors.sourceUrl),
        ),
        client: source.organization || null,
        deadline: this._read($, $el, selectors.deadline) || null,
        tags: [],
        fitScorePercent: 0,
        fitReasoning: "",
      });
    });

    return createOpportunitiesFromCandidates(db, source, candidates);
  }

  /** Selector strings may be "selector" (text) or "selector@attr" (attribute). */
  _read($, $scope, selectorSpec) {
    if (!selectorSpec) return "";
    const [selector, attr] = selectorSpec.split("@");
    const $found = selector ? $scope.find(selector) : $scope;
    if (!$found.length) return "";
    return attr ? $found.attr(attr) || "" : $found.text().trim();
  }

  _resolveUrl(pageUrl, maybeRelative) {
    if (!maybeRelative) return "";
    try {
      return new URL(maybeRelative, pageUrl).toString();
    } catch {
      return maybeRelative;
    }
  }
}

module.exports = { HtmlScraperConnector };