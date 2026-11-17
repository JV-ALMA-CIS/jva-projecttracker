const { decideBuyers, archiveUpdate } = require("./lib/buyerPolicy");

/**
 * One-off cleanup applying the buyer policy (lib/buyerPolicy.js) to what is
 * already in the platform:
 * - archives public-body tenders (not donor-funded) still awaiting triage
 *   (status "discovered") — anything a person already accepted or worked
 *   on is left untouched;
 * - switches off the government tender sources (not deleted, can be
 *   switched back on in Tender Sources).
 * Archived opportunities keep all their data and can be restored.
 */

/** Tender sources that only carry Kenyan / East African public tenders. */
const GOVERNMENT_SOURCE_KEYS = [
  "ke-tenders",
  "ke-tendersoko",
  "ke-energy-pipeline",
  "ug-procurement",
  "tz-procurement",
  "rw-procurement",
];

const BATCH = 60;

async function cleanupPublicBuyers({ db, Timestamp, classify, logger = console, now = new Date() }) {
  const ts = Timestamp.fromDate(now);

  // 1. Opportunities awaiting triage.
  const snap = await db.collection("opportunities").where("status", "==", "discovered").get();
  const docs = snap.docs;
  let archived = 0;
  let kept = 0;
  const reasons = {};
  for (let i = 0; i < docs.length; i += BATCH) {
    const chunk = docs.slice(i, i + BATCH);
    const decisions = await decideBuyers(chunk.map((d) => d.data()), { classify });
    const writes = db.batch();
    let pending = 0;
    decisions.forEach((d, j) => {
      if (!d.exclude) {
        kept += 1;
        return;
      }
      writes.update(chunk[j].ref, archiveUpdate(d.reason, ts));
      reasons[d.reason] = (reasons[d.reason] || 0) + 1;
      archived += 1;
      pending += 1;
    });
    if (pending > 0) await writes.commit();
  }

  // 2. Government-only tender sources.
  const sources = await db.collection("tenderSources").where("seedKey", "in", GOVERNMENT_SOURCE_KEYS).get();
  let sourcesDisabled = 0;
  for (const s of sources.docs) {
    if (s.data().enabled === false) continue;
    await s.ref.update({
      enabled: false,
      disabledReason: "Buyer policy: Kenyan / East African public tenders are not pursued",
      updatedAt: ts,
    });
    sourcesDisabled += 1;
  }

  const result = { reviewed: docs.length, archived, kept, reasons, sourcesDisabled };
  logger.info(`cleanupPublicBuyers: ${JSON.stringify(result)}`);
  return result;
}

module.exports = { cleanupPublicBuyers, GOVERNMENT_SOURCE_KEYS };
