const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { TENDER_CONNECTORS } = require("./connectors");

/**
 * NOT ADDED TO index.js's setGlobalOptions/admin.initializeApp() here —
 * this module is require()'d from index.js (see the addition snippet at
 * the bottom of this file's comment block) so it shares the same
 * already-initialized `admin` app and global options. Do not call
 * admin.initializeApp() again in this file.
 */

function db() {
  return admin.firestore();
}

/**
 * Runs one TenderSource sync: loads the source, dispatches to its
 * registered connector, bookends the attempt with a `tenderSyncRuns`
 * document, and updates the source's lastSyncAt/lastSuccessAt/
 * lastFailureAt/healthScore/opportunitiesImported on completion.
 *
 * Same lifecycle as Milestone 3.7's `runDiscoverySource`
 * (running -> completed/failed, always visible in history even on
 * failure) — shared with `scheduledTenderSourceSync` below so manual and
 * scheduled runs behave identically.
 */
async function runSync(sourceId, trigger) {
  const sourceRef = db().collection("tenderSources").doc(sourceId);
  const sourceSnap = await sourceRef.get();
  if (!sourceSnap.exists) {
    throw new HttpsError("not-found", "Tender source not found");
  }
  const source = { id: sourceId, ...sourceSnap.data() };

  const runsCollection = db().collection("tenderSyncRuns");
  const connector = TENDER_CONNECTORS[source.discoveryMethod];
  const startedAt = admin.firestore.Timestamp.now();

  if (!connector) {
    await runsCollection.add({
      sourceId,
      sourceName: source.name || "",
      discoveryMethod: source.discoveryMethod || "unknown",
      status: "failed",
      trigger,
      candidatesFound: 0,
      opportunitiesCreated: 0,
      duplicatesSkipped: 0,
      errorMessage: `No connector registered for discovery method "${source.discoveryMethod}".`,
      startedAt,
      completedAt: admin.firestore.Timestamp.now(),
    });
    throw new HttpsError(
      "unimplemented",
      `No connector registered for discovery method "${source.discoveryMethod}".`,
    );
  }

  const runRef = await runsCollection.add({
    sourceId,
    sourceName: source.name || "",
    discoveryMethod: source.discoveryMethod,
    status: "running",
    trigger,
    candidatesFound: 0,
    opportunitiesCreated: 0,
    duplicatesSkipped: 0,
    errorMessage: null,
    startedAt,
    completedAt: null,
  });

  try {
    const result = await connector.sync(source, db());
    const now = admin.firestore.Timestamp.now();

    await runRef.update({
      status: "completed",
      candidatesFound: result.candidatesFound,
      opportunitiesCreated: result.created,
      duplicatesSkipped: result.duplicatesSkipped,
      completedAt: now,
    });

    await sourceRef.update({
      lastSyncAt: now,
      lastSuccessAt: now,
      lastErrorMessage: null,
      status: "active",
      // Simple recovery-biased health score: full marks on success. A more
      // nuanced rolling average belongs to Milestone 3.8d (Analytics),
      // which has visibility into the fuller run history this endpoint
      // doesn't need to load on every sync.
      healthScore: 100,
      opportunitiesImported: admin.firestore.FieldValue.increment(
        result.created,
      ),
    });

    return { opportunitiesCreated: result.created };
  } catch (e) {
    logger.error("runTenderSourceSync: connector failed", e);
    const now = admin.firestore.Timestamp.now();
    const message = String(e && e.message ? e.message : e);

    await runRef.update({
      status: "failed",
      errorMessage: message,
      completedAt: now,
    });
    await sourceRef.update({
      lastSyncAt: now,
      lastFailureAt: now,
      lastErrorMessage: message,
      status: "error",
      healthScore: 0,
    });

    throw new HttpsError("internal", "Tender source sync failed");
  }
}

/**
 * Callable: runTenderSourceSync — { sourceId: string, trigger?: "manual" | "scheduled" }
 * -> { opportunitiesCreated: number }
 */
const runTenderSourceSync = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { sourceId, trigger } = request.data || {};
  if (!sourceId) throw new HttpsError("invalid-argument", "sourceId is required");
  if (trigger === "scheduled") {
    // Scheduled runs go through scheduledTenderSourceSync, not this callable
    // directly from a client — but harmless to allow explicitly if ever
    // called that way in a test.
  }
  return runSync(sourceId, trigger === "scheduled" ? "scheduled" : "manual");
});

/**
 * Scheduled: scheduledTenderSourceSync — runs hourly, and for each enabled,
 * non-manual TenderSource whose `syncFrequencyMinutes` has elapsed since
 * `lastSyncAt` (or which has never synced), calls the same `runSync` path
 * a manual "Run now" uses. Capped at 25 sources per invocation to stay
 * comfortably inside the 120s callable-equivalent budget; sources beyond
 * the cap are simply picked up on the next hourly run.
 */
const scheduledTenderSourceSync = onSchedule(
  { schedule: "every 60 minutes", timeoutSeconds: 540 },
  async () => {
    const now = Date.now();
    const snap = await db()
      .collection("tenderSources")
      .where("enabled", "==", true)
      .get();

    const due = snap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((source) => {
        if (source.discoveryMethod === "manual") return false;
        if (!source.lastSyncAt) return true;
        const elapsedMinutes =
          (now - source.lastSyncAt.toMillis()) / 60000;
        return elapsedMinutes >= (source.syncFrequencyMinutes || 1440);
      })
      .slice(0, 25);

    logger.info(`scheduledTenderSourceSync: ${due.length} source(s) due`);

    for (const source of due) {
      try {
        await runSync(source.id, "scheduled");
      } catch (e) {
        // runSync already wrote the failed run doc + source status —
        // just keep the batch moving so one bad source doesn't block
        // the rest.
        logger.error(`scheduledTenderSourceSync: ${source.id} failed`, e);
      }
    }
  },
);

module.exports = { runTenderSourceSync, scheduledTenderSourceSync };

// ============================================================================
// ADD TO functions/index.js (do not move the file's existing content —
// just add these two lines near the other Milestone 3.7 exports, e.g.
// right after the closing brace of exports.runDiscoverySource):
//
//   const { runTenderSourceSync, scheduledTenderSourceSync } = require("./tenderSourceSync");
//   exports.runTenderSourceSync = runTenderSourceSync;
//   exports.scheduledTenderSourceSync = scheduledTenderSourceSync;
// ============================================================================