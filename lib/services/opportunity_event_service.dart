import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';

const kOpportunityEventsCollection = 'opportunityEvents';

/// Read/write access to an opportunity's pipeline history. Events are
/// normally created as part of an atomic stage transition — see
/// `OpportunityService.transitionStage`, which writes to this same
/// collection in the same batch as the opportunity update — but `create` is
/// exposed here too for completeness/testability, matching every other
/// service in this codebase.
class OpportunityEventService {
  OpportunityEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kOpportunityEventsCollection);

  /// The full pipeline history for one opportunity, most recent first —
  /// same "most recent first" convention `updatedAt` ordering uses
  /// everywhere else in this app.
  Stream<List<OpportunityEvent>> watchByOpportunity(String opportunityId) {
    return _collection
        .where('opportunityId', isEqualTo: opportunityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OpportunityEvent.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// The most recent pipeline events across every opportunity, for a
  /// cross-opportunity "recent activity" feed. Single-field ordering, same
  /// as every other `watchAll()` in this codebase — no composite index.
  Stream<List<OpportunityEvent>> watchAll({int limit = 10}) {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OpportunityEvent.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(OpportunityEvent event) async {
    final doc = await _collection.add(event.toMap());
    return doc.id;
  }
}
