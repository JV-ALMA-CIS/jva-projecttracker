const Parser = require("rss-parser");
const {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
} = require("./tenderSourceConnector");

const parser = new Parser({ timeout: 15000 });

/**
 * RssConnector handles `discoveryMethod: "rss"` sources. Reads
 * `connectorConfig.feedUrl`, parses via `rss-parser` (add to
 * functions/package.json — see milestone report), and maps each feed item
 * directly into a candidate. No AI call — feed items are treated as
 * already-qualified opportunities from a source the administrator
 * specifically configured, matching the pattern's "manual entry doesn't
 * need AI judgment" precedent.
 *
 * `fitScorePercent` is left at 0/unset here deliberately — Match Analysis
 * (Milestone 3.4, already built) is what scores fit once the opportunity
 * exists, not the connector.
 */
class RssConnector extends TenderSourceConnector {
  async test(source) {
    const feedUrl = source.connectorConfig?.feedUrl;
    if (!feedUrl) {
      throw new Error("connectorConfig.feedUrl is required for RSS sources");
    }
    const feed = await parser.parseURL(feedUrl);
    const count = (feed.items || []).length;
    return {
      message: `Connected successfully — feed "${feed.title || feedUrl}" has ${count} item(s).`,
      sampleCount: count,
    };
  }

  async sync(source, db) {
    const feedUrl = source.connectorConfig?.feedUrl;
    if (!feedUrl) {
      throw new Error("connectorConfig.feedUrl is required for RSS sources");
    }

    const feed = await parser.parseURL(feedUrl);
    const items = feed.items || [];

    const candidates = items.map((item) => ({
      title: item.title || "",
      description: item.contentSnippet || item.content || "",
      sourceUrl: item.link || "",
      client: source.organization || null,
      deadline: null,
      tags: Array.isArray(item.categories) ? item.categories : [],
      fitScorePercent: 0,
      fitReasoning: "",
    }));

    return createOpportunitiesFromCandidates(db, source, candidates);
  }
}

module.exports = { RssConnector };