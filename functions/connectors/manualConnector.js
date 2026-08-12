const { TenderSourceConnector } = require("./tenderSourceConnector");

/**
 * ManualConnector handles `discoveryMethod: "manual"` sources. These are
 * never auto-run — opportunities are added directly from the app (same
 * "Add opportunity manually" flow Milestone 3.7 already has). This class
 * exists so `TENDER_CONNECTORS` has an entry for every enum value (no
 * silent `undefined` lookup) and so `runTenderSourceSync` gets the same
 * clean, honest error message pattern Milestone 3.7 used for unautomated
 * types — never a generic crash.
 */
class ManualConnector extends TenderSourceConnector {
  async test() {
    return {
      message: "Manual sources don't need a connection test.",
      sampleCount: null,
    };
  }

  // eslint-disable-next-line no-unused-vars
  async sync(source, db) {
    throw new Error(
      "Manual sources are not run automatically — add opportunities directly instead.",
    );
  }
}

module.exports = { ManualConnector };