const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { checkUrlReachable } = require("./connectors/tenderSourceConnector");

function db() {
  return admin.firestore();
}

/**
 * Callable: backfillSourceUrlVerification — { scanLimit?: number, startAfterId?: string }
 * -> { scanned: number, checked: number, hasMore: boolean, lastId: string | null }
 *
 * Re-runs `checkUrlReachable` (now soft-404 aware — see
 * connectors/tenderSourceConnector.js) against every opportunity that has a
 * `sourceUrl`, overwriting `sourceUrlVerified`/`sourceUrlVerifiedAt`
 * regardless of the field's current value — not just `sourceUrlVerified ==
 * null` ones. Two reasons a currently-non-null value still needs
 * re-checking: (1) anything discovered before this milestone has `null`
 * (never checked) and the client now correctly treats that as untrusted,
 * so it's worth actually resolving rather than leaving permanently
 * unverified; (2) anything discovered before the soft-404 fix may already
 * hold a stale `true` for a link that's actually dead.
 *
 * Ordered/paginated by document ID (not `sourceUrl`) specifically to avoid
 * requiring a Firestore composite index — this is a one-off maintenance
 * sweep, not a hot path, so a simple id-cursor is preferable to asking
 * Pal to provision an index for a query that runs a handful of times total.
 * `scanLimit` bounds how many *documents* are read per call (opportunities
 * without a sourceUrl are skipped but still count against this), not how
 * many are actually reachability-checked — each check can cost up to two
 * 5s-timeout HTTP requests, so keep this modest.
 *
 * Call repeatedly, passing the previous response's `lastId` back as
 * `startAfterId`, until `hasMore` is false.
 */
const backfillSourceUrlVerification = onCall(
  { timeoutSeconds: 300 },
  async (request) => {
    const { scanLimit = 50, startAfterId } = request.data || {};
    const cappedScanLimit = Math.min(Math.max(1, scanLimit), 100);

    let query = db()
      .collection("opportunities")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(cappedScanLimit);

    if (startAfterId) {
      query = query.startAfter(startAfterId);
    }

    const snap = await query.get();
    let checked = 0;
    let lastId = null;

    for (const doc of snap.docs) {
      lastId = doc.id;
      const sourceUrl = doc.get("sourceUrl");
      if (!sourceUrl) continue;

      try {
        const sourceUrlVerified = await checkUrlReachable(sourceUrl);
        await doc.ref.update({
          sourceUrlVerified,
          sourceUrlVerifiedAt: sourceUrlVerified
            ? admin.firestore.Timestamp.now()
            : null,
        });
        checked += 1;
      } catch (e) {
        // One bad candidate (e.g. a URL that throws in an unexpected way)
        // must not abort the rest of this batch — log and move on, same
        // pattern as scheduledTenderSourceSync's per-source try/catch.
        logger.error(
          `backfillSourceUrlVerification: failed to check opportunity ${doc.id}`,
          e,
        );
      }
    }

    return {
      scanned: snap.docs.length,
      checked,
      hasMore: snap.docs.length === cappedScanLimit,
      lastId,
    };
  },
);

module.exports = { backfillSourceUrlVerification };

// ============================================================================
// ADD TO functions/index.js:
//
//   const { backfillSourceUrlVerification } = require("./backfillSourceUrlVerification");
//   exports.backfillSourceUrlVerification = backfillSourceUrlVerification;
//
// HOW TO RUN IT — this is a one-off maintenance sweep, not something the
// app calls on its own, so trigger it manually (e.g. from the Firebase
// console's "Test function" panel, or a short local script using the
// Admin SDK / callable client) with an empty payload {} for the first
// call, then repeat passing { startAfterId: <lastId from previous response> }
// until the response comes back with hasMore: false. At ~50 documents
// scanned per call this will take multiple invocations for a large
// opportunities collection — that's expected and safe to pause/resume
// between calls, since each call is independently idempotent.
// ============================================================================