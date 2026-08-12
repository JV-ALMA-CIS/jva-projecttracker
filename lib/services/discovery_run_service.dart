import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';

const kDiscoveryRunsCollection = 'discoveryRuns';

/// Read/write access to the `discoveryRuns` collection — the audit trail
/// behind the Discovery History screen. Documents are normally created by
/// the `runDiscoverySource` Cloud Function, but `create` is exposed here too
/// for completeness/testability, matching every other service in this
/// codebase (e.g. `OpportunityEventService`). See the Opportunity Discovery
/// Engine (Milestone 3.7).
class DiscoveryRunService {
  DiscoveryRunService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kDiscoveryRunsCollection);

  /// Every run across every source, most recent first.
  Stream<List<DiscoveryRun>> watchAll({int limit = 50}) {
    return _collection
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DiscoveryRun.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// A single source's run history, most recent first.
  Stream<List<DiscoveryRun>> watchBySource(String sourceId) {
    return _collection
        .where('sourceId', isEqualTo: sourceId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DiscoveryRun.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(DiscoveryRun run) async {
    final doc = await _collection.add(run.toMap());
    return doc.id;
  }
}
