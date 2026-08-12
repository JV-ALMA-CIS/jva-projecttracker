const admin = require("firebase-admin");

/**
 * TenderSourceConnector — the common interface every discovery-method
 * connector implements. `runTenderSourceSync` (see
 * functions/tenderSourceSync.js) never branches on discoveryMethod itself —
 * it looks the connector up in TENDER_CONNECTORS (connectors/index.js) by
 * `source.discoveryMethod` and calls `.sync(source, db)`. Adding a new
 * discovery method means adding one new connector class + one registry
 * line; this file and tenderSourceSync.js never change.
 *
 * This replaces Milestone 3.7's `DISCOVERY_ADAPTERS` plain-object registry
 * with a class hierarchy (per the brief), while keeping the exact same
 * `{candidatesFound, created, duplicatesSkipped}` return contract so
 * `runTenderSourceSync`'s run-bookending logic is unchanged from
 * `runDiscoverySource`.
 */
class TenderSourceConnector {
  /**
   * @param {object} source - the TenderSource document (with `id`), or a
   *   not-yet-saved draft when testing before creation
   * @returns {Promise<{message: string, sampleCount: number|null}>}
   *   Should NOT write any opportunities — a dry run only. Throw on
   *   failure; testTenderSourceConnection.js catches it and returns
   *   {ok: false, message} to the client rather than propagating.
   */
  // eslint-disable-next-line no-unused-vars
  async test(source) {
    throw new Error(
      `${this.constructor.name} does not implement test() — every concrete connector must override it.`,
    );
  }

  /**
   * @param {object} source - the TenderSource document (with `id`)
   * @param {FirebaseFirestore.Firestore} db
   * @returns {Promise<{candidatesFound: number, created: number, duplicatesSkipped: number}>}
   */
  // eslint-disable-next-line no-unused-vars
  async sync(source, db) {
    throw new Error(
      `${this.constructor.name} does not implement sync() — every concrete connector must override it.`,
    );
  }
}

/**
 * Shared candidate -> Opportunity write path used by every connector.
 * Centralizing this means dedup semantics (sourceUrl equality against the
 * `opportunities` collection — same rule Milestone 3.7 used) and the
 * Opportunity field shape stay identical across all discovery methods,
 * instead of each connector re-implementing its own write loop.
 *
 * Each candidate must have at least {title, sourceUrl}; other fields are
 * optional and defaulted. `deadline`, if present, must be an ISO 8601
 * string or omitted/null.
 */
async function createOpportunitiesFromCandidates(db, source, candidates) {
  let created = 0;
  let duplicatesSkipped = 0;

  for (const c of candidates) {
    if (!c || !c.sourceUrl || !c.title) continue;

    const existing = await db
      .collection("opportunities")
      .where("sourceUrl", "==", c.sourceUrl)
      .limit(1)
      .get();
    if (!existing.empty) {
      duplicatesSkipped += 1;
      continue;
    }

    const now = admin.firestore.Timestamp.now();
    let deadline = null;
    if (c.deadline) {
      const parsed = new Date(c.deadline);
      if (!Number.isNaN(parsed.getTime())) {
        deadline = admin.firestore.Timestamp.fromDate(parsed);
      }
    }

    await db.collection("opportunities").add({
      title: c.title,
      description: c.description || "",
      sourceUrl: c.sourceUrl,
      client: c.client || null,
      deadline,
      status: "discovered",
      fitScorePercent: Math.max(
        0,
        Math.min(100, Math.round(c.fitScorePercent || 0)),
      ),
      fitReasoning: c.fitReasoning || "",
      tags: Array.isArray(c.tags) ? c.tags : [],
      discoveredAt: now,
      updatedAt: now,
      // Legacy fields kept for any code still reading discoverySource* —
      // intentionally left null here since this write path only ever runs
      // from a TenderSource, never a legacy DiscoverySource.
      discoverySourceId: null,
      discoverySourceType: null,
      tenderSourceId: source.id,
      tenderSourceCategory: source.category,
      tenderDiscoveryMethod: source.discoveryMethod,
    });
    created += 1;
  }

  return { candidatesFound: candidates.length, created, duplicatesSkipped };
}

module.exports = { TenderSourceConnector, createOpportunitiesFromCandidates };