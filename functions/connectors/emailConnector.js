const admin = require("firebase-admin");
const {
  TenderSourceConnector,
  createOpportunitiesFromCandidates,
} = require("./tenderSourceConnector");

/**
 * EmailConnector handles `discoveryMethod: "email"` sources.
 *
 * Honest scope note: real inbox monitoring (IMAP polling or Gmail API push
 * notifications) needs its own OAuth/credential setup — a separate task
 * from this milestone. Rather than register a `null` adapter the way
 * Milestone 3.7 did for rss/api, this connector does real work against a
 * `tenderEmailInboxItems` staging collection: a future ingestion function
 * (triggered by a mail-forwarding webhook, or a scheduled IMAP poll) writes
 * one document per parsed email there; this connector consumes unprocessed
 * ones scoped to `source.id` and marks them processed. That keeps the
 * connector interface genuinely functional today and means the only
 * remaining work later is the ingestion side, not this class.
 *
 * Expected `tenderEmailInboxItems` document shape:
 * { sourceId, subject, sender, receivedAt, extractedTitle, extractedUrl,
 *   extractedDescription, extractedDeadline, processed: false }
 */
class EmailConnector extends TenderSourceConnector {
  async test(source, db) {
    // db is optional here since test() is only declared to take `source` in
    // the base contract, but EmailConnector needs Firestore to check the
    // staging collection — accessed via admin.firestore() directly rather
    // than widening the shared interface for one connector's needs.
    const fsDb = db || admin.firestore();
    const snap = await fsDb
      .collection("tenderEmailInboxItems")
      .where("sourceId", "==", source.id || "draft")
      .where("processed", "==", false)
      .limit(1)
      .get();
    return {
      message: snap.empty
        ? "No unprocessed emails staged for this source yet. This is expected until a mail-ingestion pipeline is wired up to write to tenderEmailInboxItems."
        : "Found unprocessed staged email(s) ready to import.",
      sampleCount: null,
    };
  }

  async sync(source, db) {
    const inboxCollection = db.collection("tenderEmailInboxItems");
    const snap = await inboxCollection
      .where("sourceId", "==", source.id)
      .where("processed", "==", false)
      .limit(50)
      .get();

    const candidates = snap.docs.map((d) => {
      const item = d.data();
      return {
        title: item.extractedTitle || item.subject || "",
        description: item.extractedDescription || "",
        sourceUrl: item.extractedUrl || "",
        client: source.organization || null,
        deadline: item.extractedDeadline || null,
        tags: [],
        fitScorePercent: 0,
        fitReasoning: "",
      };
    });

    const result = await createOpportunitiesFromCandidates(
      db,
      source,
      candidates,
    );

    const batch = db.batch();
    for (const d of snap.docs) {
      batch.update(d.ref, {
        processed: true,
        processedAt: admin.firestore.Timestamp.now(),
      });
    }
    if (snap.docs.length) await batch.commit();

    return result;
  }
}

module.exports = { EmailConnector };