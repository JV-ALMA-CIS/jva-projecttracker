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

    // Surface the connector's actual error text (e.g. a Vertex AI quota
    // message) to the client rather than a generic failure — the same
    // message already saved to errorMessage above, so both the immediate
    // snackbar and the Sync History tooltip agree.
    throw new HttpsError("internal", message);
  }
}

/**
 * Callable: runTenderSourceSync — { sourceId: string, trigger?: "manual" | "scheduled" }
 * -> { opportunitiesCreated: number }
 *
 * 240s (up from 120s): `createOpportunitiesFromCandidates` now does a real
 * HTTP reachability check (up to two requests, 5s timeout each) per
 * candidate before writing it — up to 8 candidates from a single aiSearch
 * run, on top of the Gemini call itself, needs real headroom over the
 * previous budget.
 */
const runTenderSourceSync = onCall({ timeoutSeconds: 240 }, async (request) => {
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
 * comfortably inside this function's own 540s budget; sources beyond the
 * cap are simply picked up on the next hourly run. If the per-candidate
 * sourceUrl reachability check (createOpportunitiesFromCandidates) ever
 * makes a single source noticeably slower, per-source failures/timeouts
 * are caught and logged below without aborting the rest of the batch — a
 * slow/timed-out source just gets retried on the next hourly pass.
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

/**
 * Runs [runnable] sources one after another in the background, same as
 * scheduledTenderSourceSync's loop — extracted so runAllTenderSourcesNow
 * can fire this off without awaiting it (see that callable's doc comment
 * for why: 25 sources' worth of real Gemini + Google Search calls plus
 * per-candidate reachability checks routinely takes well past the ~9-minute
 * ceiling Cloud Functions v2 HTTPS callables allow, and the Flutter client
 * was already timing out at 540s waiting on it — "deadline-exceeded" even
 * though the batch was still genuinely progressing server-side).
 */
async function runSourcesInBackground(runnable) {
  for (const source of runnable) {
    try {
      await runSync(source.id, "manual");
    } catch (e) {
      // runSync already wrote the failed run doc + source status — just
      // keep the batch moving so one bad source doesn't block the rest.
      logger.error(`runAllTenderSourcesNow: ${source.id} failed`, e);
    }
  }
  logger.info(`runAllTenderSourcesNow: finished batch of ${runnable.length}`);
}

/**
 * Callable: runAllTenderSourcesNow — {} -> { queued: number }
 *
 * Manual "run everything now" for the Tender Sources screen — with 30+
 * sources configured, running each one individually via `runTenderSourceSync`
 * one at a time in the UI is not a workable workflow. Unlike
 * `scheduledTenderSourceSync`, this ignores each source's
 * `syncFrequencyMinutes`/`lastSyncAt` due-check entirely — an explicit "run
 * all now" click means run all enabled, non-manual sources regardless of
 * when they last ran.
 *
 * Fire-and-forget: this callable resolves as soon as the batch is queued
 * (a couple of Firestore reads), NOT after every source finishes — the
 * loop itself (`runSourcesInBackground`) keeps running after the response
 * is sent. This is deliberate, not a bug: a synchronous "wait for all N
 * sources" response was the original design and it genuinely can't fit in
 * a callable's response window at this batch size. Progress is already
 * visible without polling this call — each source's `lastSyncAt`/
 * `lastSuccessAt`/`healthScore` updates live (Tender Sources screen watches
 * `tenderSourcesStreamProvider`), and every attempt lands in Sync History
 * (`tenderSyncRuns`) via the same `runSync` bookkeeping every other trigger
 * uses.
 *
 * Still capped (MAX_SOURCES_PER_RUN) per click — a portfolio larger than
 * the cap gets the rest on the next manual click or the next scheduled
 * hourly pass.
 *
 * Admin-gated like every other bulk/maintenance action in this codebase
 * (seedProductionTenderSources, backfillTenderSourceWebsites, etc.) —
 * running 30+ real Gemini + Google Search calls at once has a real cost.
 */
const MAX_SOURCES_PER_RUN = 25;

const runAllTenderSourcesNow = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can run all tender sources",
      );
    }

    const snap = await db()
      .collection("tenderSources")
      .where("enabled", "==", true)
      .get();

    const runnable = snap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((source) => source.discoveryMethod !== "manual")
      .slice(0, MAX_SOURCES_PER_RUN);

    logger.info(`runAllTenderSourcesNow: queuing ${runnable.length} source(s)`);

    // Deliberately not awaited — see doc comment above. Errors inside the
    // background loop are caught per-source within it and never reach
    // here, so this can't reject after the response has already been sent.
    runSourcesInBackground(runnable);

    return { queued: runnable.length };
  },
);

module.exports = {
  runTenderSourceSync,
  scheduledTenderSourceSync,
  runAllTenderSourcesNow,
};
