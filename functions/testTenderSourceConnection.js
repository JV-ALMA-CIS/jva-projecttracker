const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { TENDER_CONNECTORS } = require("./connectors");

function db() {
  return admin.firestore();
}

/**
 * Callable: testTenderSourceConnection
 *
 * Request shape — exactly one of:
 *   { sourceId: string }                 — test an already-saved source
 *   { draft: { discoveryMethod, connectorConfig, authConfig, category,
 *              name, organization } }    — test before saving (Add Source
 *                                          dialog's "Test connection")
 *
 * Always returns { ok, message, sampleCount } — never throws to the
 * client, since a failed test is an expected, common outcome the UI
 * should display inline, not an error state.
 */
const testTenderSourceConnection = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    const { sourceId, draft } = request.data || {};
    let source;

    if (sourceId) {
      const snap = await db().collection("tenderSources").doc(sourceId).get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Tender source not found");
      }
      source = { id: sourceId, ...snap.data() };
    } else if (draft) {
      source = { id: "draft", ...draft };
    } else {
      throw new HttpsError(
        "invalid-argument",
        "Either sourceId or draft is required",
      );
    }

    const connector = TENDER_CONNECTORS[source.discoveryMethod];
    if (!connector) {
      return {
        ok: false,
        message: `No connector registered for discovery method "${source.discoveryMethod}".`,
        sampleCount: null,
      };
    }

    try {
      const result = await connector.test(source, db());
      return { ok: true, message: result.message, sampleCount: result.sampleCount };
    } catch (e) {
      logger.warn("testTenderSourceConnection: test failed", e);
      return { ok: false, message: String(e && e.message ? e.message : e), sampleCount: null };
    }
  },
);

module.exports = { testTenderSourceConnection };

// ============================================================================
// ADD TO functions/index.js, alongside the tenderSourceSync.js addition:
//
//   const { testTenderSourceConnection } = require("./testTenderSourceConnection");
//   exports.testTenderSourceConnection = testTenderSourceConnection;
// ============================================================================