import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/submission_communication.dart';

/// CRUD + live queries for [SubmissionCommunication] — its own collection
/// keyed by `submissionId`, same shape as `ProposalSectionService` relative
/// to `Proposal`.
class SubmissionCommunicationService {
  SubmissionCommunicationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('submissionCommunications');

  /// All logged communications for one submission, most recent first.
  Stream<List<SubmissionCommunication>> watchBySubmissionId(
    String submissionId,
  ) {
    return _collection
        .where('submissionId', isEqualTo: submissionId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubmissionCommunication.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> create(SubmissionCommunication communication) {
    return _collection.add(communication.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
