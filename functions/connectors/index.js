const { ApiConnector } = require("./apiConnector");
const { RssConnector } = require("./rssConnector");
const { HtmlScraperConnector } = require("./htmlScraperConnector");
const { EmailConnector } = require("./emailConnector");
const { ManualConnector } = require("./manualConnector");

/**
 * The single dispatch point: `source.discoveryMethod` -> connector
 * instance. `runTenderSourceSync` (tenderSourceSync.js) looks up here and
 * calls `.sync(source, db)` — it never branches on discoveryMethod itself.
 *
 * TO ADD A NEW DISCOVERY METHOD:
 *   1. Add the value to TenderDiscoveryMethod in
 *      lib/models/tender_source.dart (Dart/Flutter side).
 *   2. Write a new connector class extending TenderSourceConnector.
 *   3. Register it below.
 * Nothing else in the Discovery Engine needs to change.
 */
const TENDER_CONNECTORS = {
  api: new ApiConnector(),
  rss: new RssConnector(),
  htmlScraping: new HtmlScraperConnector(),
  email: new EmailConnector(),
  manual: new ManualConnector(),
};

module.exports = { TENDER_CONNECTORS };