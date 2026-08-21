const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { SEED_SOURCES } = require("./seedTenderSources");

function db() {
  return admin.firestore();
}

/**
 * Callable: backfillTenderSourceWebsites — one-time correction for existing
 * `tenderSources` docs whose `website` field was seeded wrong before a web
 * audit fixed `SEED_SOURCES` in seedTenderSources.js (many pointed at an
 * org's marketing homepage instead of its actual tender/procurement listing
 * page, or claimed a page existed when the org has no public listing at
 * all — see that file's per-source comments for what changed and why).
 *
 * `seedProductionTenderSources` is idempotent by `seedKey` and skips docs
 * that already exist, so correcting SEED_SOURCES alone never reaches
 * sources that were seeded before the fix — this callable is what actually
 * applies the corrected `website` values to those existing docs. Matched by
 * `seedKey` (falls back to nothing for docs without one — this only ever
 * touches sources that trace back to SEED_SOURCES). Only overwrites
 * `website` when it actually differs, so it's safe to call more than once.
 */
const backfillTenderSourceWebsites = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }
    const userSnap = await db().collection("users").doc(request.auth.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can backfill tender source websites",
      );
    }

    const websiteBySeedKey = new Map(
      SEED_SOURCES.map((seed) => [seed.seedKey, seed.website]),
    );

    const existingSnap = await db().collection("tenderSources").get();
    const now = admin.firestore.Timestamp.now();
    const batch = db().batch();

    let updated = 0;
    let unchanged = 0;
    let skippedNoSeedMatch = 0;
    const updatedSeedKeys = [];

    for (const doc of existingSnap.docs) {
      const seedKey = doc.data().seedKey;
      if (typeof seedKey !== "string" || !websiteBySeedKey.has(seedKey)) {
        skippedNoSeedMatch += 1;
        continue;
      }

      const correctedWebsite = websiteBySeedKey.get(seedKey);
      const currentWebsite = doc.data().website ?? null;
      if (correctedWebsite === currentWebsite) {
        unchanged += 1;
        continue;
      }

      batch.update(doc.ref, { website: correctedWebsite, updatedAt: now });
      updated += 1;
      updatedSeedKeys.push(seedKey);
    }

    if (updated > 0) await batch.commit();

    logger.info(
      `backfillTenderSourceWebsites: updated ${updated}, unchanged ${unchanged}, skipped ${skippedNoSeedMatch} (no seed match). Updated: ${updatedSeedKeys.join(", ")}`,
    );

    return { updated, unchanged, skippedNoSeedMatch, updatedSeedKeys };
  },
);

module.exports = { backfillTenderSourceWebsites };
