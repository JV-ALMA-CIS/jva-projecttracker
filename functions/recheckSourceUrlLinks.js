const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { checkUrlReachable } = require("./connectors/tenderSourceConnector");

function db() {
  return admin.firestore();
}

/**
 * Statuses treated as "closed out" — an opportunity here is no longer
 * being pursued, so its sourceUrl isn't worth spending a re-check on even
 * if it's since gone dead.
 *
 * NOTE: inferred from OpportunityStatus usages seen across the Discovery
 * Engine screens (won/lost/dismissed/archived, via
 * OpportunityStatus.dismissed/archived in opportunity_inbox_screen.dart
 * and isWonOpportunity()/closedReason handling in opportunities_screen.dart
 * and opportunity_pipeline_screen.dart) — confirm this list matches every
 * terminal value in lib/models/opportunity.dart's OpportunityStatus enum
 * before deploying, and update it if the enum gains further terminal
 * states later.
 */
const TERMINAL_STATUSES = ["won", "lost", "dismissed", "archived"];

/**
 * Scheduled: recheckSourceUrlLinks — runs weekly. A `sourceUrl` correctly
 * verified at discovery time can still rot afterward (the tender closes
 * and the page is pulled, the site restructures its URLs, a government
 * portal migrates) — nothing before this ever looked at a link again once
 * it was first checked. This re-checks `sourceUrl` for every opportunity
 * NOT in a terminal status, using the same soft-404-aware
 * `checkUrlReachable` as discovery time, so a link that quietly died after
 * being marked verified gets its warning badge back.
 *
 * Capped at 40 opportunities per run for the same reason
 * scheduledTenderSourceSync caps itself at 25 sources — bounded HTTP work
 * per invocation, comfortably inside this function's timeout budget.
 * Anything beyond the cap is simply picked up on the following week's run,
 * so coverage catches up over time rather than needing to fit in one pass.
 */
const recheckSourceUrlLinks = onSchedule(
  { schedule: "every monday 03:00", timeoutSeconds: 480 },
  async () => {
    const snap = await db()
      .collection("opportunities")
      .where("status", "not-in", TERMINAL_STATUSES)
      .limit(40)
      .get();

    const candidates = snap.docs.filter((d) => !!d.get("sourceUrl"));
    logger.info(
      `recheckSourceUrlLinks: re-checking ${candidates.length} of ${snap.docs.length} active opportunit(y/ies)`,
    );

    for (const doc of candidates) {
      try {
        const sourceUrlVerified = await checkUrlReachable(doc.get("sourceUrl"));
        await doc.ref.update({
          sourceUrlVerified,
          sourceUrlVerifiedAt: sourceUrlVerified
            ? admin.firestore.Timestamp.now()
            : null,
        });
      } catch (e) {
        logger.error(`recheckSourceUrlLinks: failed for ${doc.id}`, e);
      }
    }
  },
);

module.exports = { recheckSourceUrlLinks };

// ============================================================================
// ADD TO functions/index.js, alongside scheduledTenderSourceSync:
//
//   const { recheckSourceUrlLinks } = require("./recheckSourceUrlLinks");
//   exports.recheckSourceUrlLinks = recheckSourceUrlLinks;
// ============================================================================