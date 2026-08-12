const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

function db() {
  return admin.firestore();
}

/**
 * Keeps `tenderSources/{id}`'s wins/losses/historicalWinRatePercent AND
 * aiQualityScore in sync with its opportunities. Without this, these
 * fields — part of the TenderSource schema since Milestone 3.8a and
 * already surfaced in the Source Workspace, Discovery Dashboard, and
 * Analytics UIs — were permanently stuck at their zero/null defaults,
 * since nothing ever wrote to them.
 *
 * Two independent triggers live in one function, since both react to the
 * same document and there's no reason to pay for two separate invocations:
 *
 *  - win/loss: handles reclassification correctly (an opportunity moving
 *    won -> lost, or back to reviewing) by comparing before/after status
 *    rather than only reacting to "became won/lost", so a corrected status
 *    doesn't leave a stale win or loss counted forever.
 *
 *  - aiQualityScore: recomputed as the source's average `fitScorePercent`
 *    across all its opportunities, whenever a new fit score lands (i.e.
 *    after AI Classification runs — see askGemini/classifyOpportunity).
 *    This does one extra query per triggering write (all opportunities for
 *    that source) — fine at current scale; if a source accumulates
 *    thousands of opportunities this should move to an incrementally
 *    maintained running average instead of a full recompute.
 */
const onTenderOpportunityOutcome = onDocumentUpdated(
  "opportunities/{opportunityId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after.tenderSourceId) return;

    const wasWon = before.status === "won";
    const wasLost = before.status === "lost";
    const isWon = after.status === "won";
    const isLost = after.status === "lost";

    const winsDelta = (isWon ? 1 : 0) - (wasWon ? 1 : 0);
    const lossesDelta = (isLost ? 1 : 0) - (wasLost ? 1 : 0);

    const fitScoreChanged =
      typeof after.fitScorePercent === "number" &&
      after.fitScorePercent !== before.fitScorePercent;

    if (winsDelta === 0 && lossesDelta === 0 && !fitScoreChanged) return;

    const sourceRef = db()
      .collection("tenderSources")
      .doc(after.tenderSourceId);

    try {
      // Done outside the transaction: reading a whole-collection query
      // inside a Firestore transaction just adds contention for no
      // benefit here — a slightly-stale average on a rare concurrent
      // write is an acceptable tradeoff for not serializing every sync's
      // opportunity writes against each other.
      let newAiQualityScore;
      if (fitScoreChanged) {
        const snap = await db()
          .collection("opportunities")
          .where("tenderSourceId", "==", after.tenderSourceId)
          .get();
        const scores = snap.docs
          .map((d) => d.data().fitScorePercent)
          .filter((s) => typeof s === "number");
        if (scores.length > 0) {
          newAiQualityScore = Math.round(
            scores.reduce((a, b) => a + b, 0) / scores.length,
          );
        }
      }

      await db().runTransaction(async (tx) => {
        const snap = await tx.get(sourceRef);
        if (!snap.exists) return;
        const data = snap.data();

        const update = { updatedAt: admin.firestore.Timestamp.now() };

        if (winsDelta !== 0 || lossesDelta !== 0) {
          const wins = Math.max(0, (data.wins || 0) + winsDelta);
          const losses = Math.max(0, (data.losses || 0) + lossesDelta);
          const total = wins + losses;
          update.wins = wins;
          update.losses = losses;
          update.historicalWinRatePercent =
            total > 0 ? (wins / total) * 100 : null;
        }

        if (newAiQualityScore !== undefined) {
          update.aiQualityScore = newAiQualityScore;
        }

        tx.update(sourceRef, update);
      });
    } catch (e) {
      // Never let an analytics side-effect fail the opportunity write that
      // triggered it — the write already committed by the time this runs.
      logger.error(
        `onTenderOpportunityOutcome: failed to update source ${after.tenderSourceId}`,
        e,
      );
    }
  },
);

module.exports = { onTenderOpportunityOutcome };

// ============================================================================
// No index.js change needed if you already wired this in for 3.8d — the
// export name is unchanged, only its internal behavior grew. If not yet
// wired, add alongside the other Tender Source exports:
//
//   const { onTenderOpportunityOutcome } = require("./tenderSourceAnalytics");
//   exports.onTenderOpportunityOutcome = onTenderOpportunityOutcome;
// ============================================================================