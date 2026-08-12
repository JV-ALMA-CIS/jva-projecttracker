import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';

/// Live-stream access to the `tenderSyncRuns` audit trail, written by the
/// `runTenderSourceSync` Cloud Function. Read-only from the client — see
/// TenderSyncService for triggering a run.
class TenderSyncRunService {
  TenderSyncRunService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tenderSyncRuns');

  Stream<List<TenderSyncRun>> watchAll() {
    return _collection
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TenderSyncRun.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<TenderSyncRun>> watchBySource(String sourceId) {
    return _collection
        .where('sourceId', isEqualTo: sourceId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TenderSyncRun.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
