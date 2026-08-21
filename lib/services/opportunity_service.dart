import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';

const _kOpportunitiesCollection = 'opportunities';

class OpportunityService {
  OpportunityService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsOverride = functions;

  final FirebaseFirestore _firestore;

  // Resolved lazily (rather than in the initializer list) so constructing an
  // OpportunityService with only a fake Firestore — the shape every
  // model/service test in this app uses — doesn't require Firebase Core to
  // be initialized. Only `triggerDiscoveryRun` ever touches this.
  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_kOpportunitiesCollection);

  Stream<List<Opportunity>> watchAll() {
    return _watchCollection(_collection);
  }

  Stream<List<Opportunity>> watchByStatus(OpportunityStatus status) {
    return _watchCollection(_collection, status: status);
  }

  Stream<List<Opportunity>> _watchCollection(
    CollectionReference<Map<String, dynamic>> collection, {
    OpportunityStatus? status,
  }) {
    final query = status != null
        ? collection
              .where('status', isEqualTo: status.name)
              .orderBy('fitScorePercent', descending: true)
        : collection.orderBy('fitScorePercent', descending: true);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Opportunity.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<Opportunity?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Opportunity.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Manual-import write path — used by [DiscoverySourceType.manual] entries
  /// added directly from the Discovery Sources screen, with no AI/Cloud
  /// Function involved. Every other opportunity today is still created by
  /// the `searchOpportunities`/`scheduledOpportunityDiscovery`/
  /// `runDiscoverySource` Cloud Functions via the Admin SDK.
  Future<String> create(Opportunity opportunity) async {
    final doc = await _collection.add(opportunity.toMap());
    return doc.id;
  }

  Future<void> updateStatus(String id, OpportunityStatus status) {
    return _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Narrow write path for the Opportunity Workspace's manual Business
  /// Units picker — same shape as [updateStatus]. This is the always-
  /// available correction tool: a human explicitly setting/clearing BUs
  /// here always wins over anything an AI classification run wrote or
  /// will write (see `classifyOpportunity`'s empty-only guard in
  /// `functions/index.js`).
  Future<void> updateBusinessUnitIds(String id, List<String> businessUnitIds) {
    return _collection.doc(id).update({
      'businessUnitIds': businessUnitIds,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Manual override for [Opportunity.sourceUrlVerified] — the escape hatch
  /// for the false-negative case where the discovery-time HTTP check
  /// (`createOpportunitiesFromCandidates` in functions/connectors/
  /// tenderSourceConnector.js) fails not because the link is fake, but
  /// because the real site blocks automated requests (some government/
  /// embassy sites do this to bots while working fine in a real browser).
  /// A human who has actually opened the link and confirmed it's real
  /// calls this from `OpenSourceLinkButton`'s "Mark as verified" action.
  Future<void> markSourceUrlVerified(String id) {
    final now = Timestamp.now();
    return _collection.doc(id).update({
      'sourceUrlVerified': true,
      'sourceUrlVerifiedAt': now,
      'updatedAt': now,
    });
  }

  /// Narrow write path for the Opportunity Workspace's manual Eligibility
  /// requirements editor — same shape as [updateBusinessUnitIds]. Kept
  /// separate from AI-written fields since certification requirements are
  /// always entered by hand (see [OpportunityCertificationRequirement]'s
  /// doc comment on why this stays out of scope for AI extraction).
  Future<void> updateRequiredCertifications(
    String id,
    List<OpportunityCertificationRequirement> requiredCertifications,
  ) {
    return _collection.doc(id).update({
      'requiredCertifications': requiredCertifications
          .map((r) => r.toMap())
          .toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Full-document update — used by the classification editor, which
  /// touches many fields (relationships, priority, risk, etc.) at once.
  /// [updateStatus] stays as the narrow status-only path used by the
  /// opportunity list's inline status dropdown.
  Future<void> update(Opportunity opportunity) {
    return _collection.doc(opportunity.id).update(opportunity.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  /// Deletes every opportunity whose `tenderSourceId` is [tenderSourceId] —
  /// used when an admin deletes a `TenderSource` and wants its already-
  /// imported opportunities gone too, rather than orphaned forever (deleting
  /// the source document alone never touches `opportunities`, since the two
  /// collections have no cascade-delete link). Returns the number deleted.
  /// Batched in chunks of 400 (under Firestore's 500-write batch limit,
  /// leaving headroom) since a well-used source can have produced more
  /// opportunities than fit in a single batch.
  Future<int> deleteByTenderSourceId(String tenderSourceId) async {
    final snapshot = await _collection
        .where('tenderSourceId', isEqualTo: tenderSourceId)
        .get();
    final docs = snapshot.docs;
    for (var i = 0; i < docs.length; i += 400) {
      final chunk = docs.skip(i).take(400);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return docs.length;
  }

  /// Bulk-deletes every opportunity in [ids] — the cleanup path for
  /// opportunities orphaned by a `TenderSource` that was deleted before
  /// [deleteByTenderSourceId] existed (its `tenderSourceId` field still
  /// points at a document that's already gone, so it can no longer be
  /// looked up that way; callers instead find matches client-side by title/
  /// client/sourceUrl keyword — see `opportunities_screen.dart`'s bulk
  /// cleanup dialog — and pass the resulting ids here). Same 400-per-batch
  /// chunking as [deleteByTenderSourceId]. Returns the number deleted.
  Future<int> deleteByIds(List<String> ids) async {
    for (var i = 0; i < ids.length; i += 400) {
      final chunk = ids.skip(i).take(400);
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.delete(_collection.doc(id));
      }
      await batch.commit();
    }
    return ids.length;
  }

  /// Atomically moves an opportunity to [newStage]: updates
  /// `pipelineStage`/`lastStageUpdated`/`updatedAt` on the opportunity
  /// document and appends a corresponding [OpportunityEvent] to
  /// `opportunityEvents`, in a single Firestore batch write so the two can
  /// never end up out of sync (an opportunity claiming one stage with no
  /// event explaining how it got there). The event's `title` is plain
  /// English, generated from the enum's own `.label` — services in this
  /// app never depend on `AppStrings`, so the stored audit trail isn't
  /// localized; only the UI rendering it is.
  Future<void> transitionStage({
    required String opportunityId,
    required OpportunityPipelineStage newStage,
    String? note,
    String? actor,
  }) async {
    final opportunityRef = _collection.doc(opportunityId);
    final snapshot = await opportunityRef.get();
    final data = snapshot.data();
    final fromStage = OpportunityPipelineStageX.fromString(
      data?['pipelineStage'] as String? ?? 'discovered',
    );

    final now = Timestamp.now();
    final eventRef = _firestore.collection(kOpportunityEventsCollection).doc();
    final event = OpportunityEvent(
      id: eventRef.id,
      opportunityId: opportunityId,
      stage: newStage,
      title: 'Stage changed to ${newStage.label}',
      description: note ?? '',
      createdAt: now.toDate(),
      createdBy: actor,
      metadata: {'fromStage': fromStage.name, 'toStage': newStage.name},
    );

    final batch = _firestore.batch();
    batch.update(opportunityRef, {
      'pipelineStage': newStage.name,
      'lastStageUpdated': now,
      'updatedAt': now,
    });
    batch.set(eventRef, event.toMap());
    await batch.commit();
  }

  /// Records the human business decision on an opportunity's Strategic
  /// Review — a narrow field-only update (same shape as [updateStatus]/
  /// [linkExperience]), deliberately never touching
  /// `executiveRecommendation` or any other AI-written field. The AI
  /// recommendation and the human decision are two separate, independently
  /// persisted values by design: recording a decision must never overwrite
  /// or erase what the AI actually said, even when the human disagrees
  /// with it.
  Future<void> recordStrategicDecision({
    required String opportunityId,
    required StrategicReviewRecommendation decision,
    String? reason,
    String? decidedBy,
  }) {
    final now = Timestamp.now();
    return _collection.doc(opportunityId).update({
      'humanDecision': decision.name,
      'humanDecisionReason': reason,
      'humanDecisionBy': decidedBy,
      'humanDecisionAt': now,
      'updatedAt': now,
    });
  }

  /// Triggers the `searchOpportunities` callable Cloud Function, which runs a web
  /// search for new opportunities and scores each one against the company's
  /// project/application history via Gemini. Results are written to Firestore
  /// by the function itself.
  Future<int> triggerDiscoveryRun({String? query}) async {
    final callable = _functions.httpsCallable(
      'searchOpportunities',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 240)),
    );
    final result = await callable.call<Map<String, dynamic>>({'query': query});
    return (result.data['created'] as num?)?.toInt() ?? 0;
  }
}
