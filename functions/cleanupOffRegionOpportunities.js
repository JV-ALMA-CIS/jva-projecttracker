const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { isAllowedCountry } = require("./opportunityRelevance");

function db() {
  return admin.firestore();
}

const MAX_BATCH_SIZE = 400;

/**
 * Callable: cleanupOffRegionOpportunities — { dryRun?: boolean, limit?: number }
 *
 * One-time admin-gated cleanup for opportunities written BEFORE the
 * isAllowedCountry hard geography filter existed (see
 * opportunityRelevance.js) — sources like CanadaBuys, SAM.gov, and UK Find
 * a Tender legitimately stay enabled (their AI search can surface real
 * Kenya/East-Africa-funded work), but earlier syncs, run before this filter
 * was added, wrote whatever the model returned unfiltered — including
 * Toronto/Botswana/North Carolina tenders with no connection to Kenya,
 * Uganda, Tanzania, Rwanda, or Burundi.
 *
 * Applies the SAME isAllowedCountry check every new sync already runs
 * before writing, to each EXISTING opportunity document's
 * title/description/client. `dryRun: true` (the default) only counts and
 * lists what would be deleted — nothing is removed until called again with
 * `dryRun: false`. Batched (`MAX_BATCH_SIZE` per call, Firestore's batch
 * write limit) — call again (or raise `limit`, capped at `MAX_BATCH_SIZE`)
 * to work through a larger backlog.
 */
const cleanupOffRegionOpportunities = onCall(
  { timeoutSeconds: 300 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can clean up off-region opportunities",
      );
    }

    // Defaults to true — a destructive bulk delete must be opted into
    // explicitly, never the default behavior of calling this function.
    const dryRun = request.data?.dryRun !== false;
    const requestedLimit = Number(request.data?.limit);
    const limit = Number.isFinite(requestedLimit) && requestedLimit > 0
      ? Math.min(requestedLimit, MAX_BATCH_SIZE)
      : MAX_BATCH_SIZE;

    const opportunitiesSnap = await db().collection("opportunities").limit(2000).get();
    const offRegion = opportunitiesSnap.docs.filter((d) => {
      const data = d.data();
      // Never touch an opportunity a human has already acted on — a closed
      // pipeline stage means real work (a proposal, a submission, a won/lost
      // outcome) may already be attached to it; deleting it would destroy
      // that history. Cleanup only ever targets untouched, still-open
      // discovered/reviewing opportunities.
      const status = data.status;
      if (status && status !== "discovered" && status !== "reviewing") {
        return false;
      }
      return !isAllowedCountry({
        title: data.title,
        description: data.description,
        client: data.client,
      });
    });

    const batch = offRegion.slice(0, limit);
    const preview = batch.map((d) => ({
      id: d.id,
      title: d.data().title,
      client: d.data().client || null,
      tenderSourceId: d.data().tenderSourceId || null,
    }));

    if (dryRun) {
      logger.info(
        `cleanupOffRegionOpportunities: dry run — ${offRegion.length} off-region opportunity(ies) found ` +
          `(${batch.length} in this preview batch), nothing deleted`,
      );
      return {
        dryRun: true,
        totalOffRegion: offRegion.length,
        previewCount: preview.length,
        preview,
      };
    }

    let deleted = 0;
    for (let i = 0; i < batch.length; i += MAX_BATCH_SIZE) {
      const chunk = batch.slice(i, i + MAX_BATCH_SIZE);
      const writeBatch = db().batch();
      for (const doc of chunk) {
        writeBatch.delete(doc.ref);
      }
      await writeBatch.commit();
      deleted += chunk.length;
    }

    logger.info(
      `cleanupOffRegionOpportunities: deleted ${deleted} off-region opportunity(ies) ` +
        `(${offRegion.length - deleted} remaining for a future call)`,
    );

    return {
      dryRun: false,
      deleted,
      remaining: offRegion.length - deleted,
    };
  },
);

module.exports = { cleanupOffRegionOpportunities };
