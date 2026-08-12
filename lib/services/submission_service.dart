import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/submission.dart';

/// CRUD + live queries for [Submission] — one per opportunity by
/// convention, same shape as `ProposalService`. Firestore relationships
/// stay as plain ID fields (`opportunityId`, `proposalId`), never embedded,
/// per this project's architecture rule.
class SubmissionService {
  SubmissionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('submissions');

  /// Every submission, live, most recently updated first — backs the
  /// Dashboard's submissions section, the command palette's per-submission
  /// entries, and the Business Unit Workspace's submission rollup.
  Stream<List<Submission>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Submission.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// The current submission for one opportunity, live — `null` if none has
  /// been started yet (an honest empty state, same convention as every
  /// other per-opportunity workspace panel in this app).
  Stream<Submission?> watchByOpportunityId(String opportunityId) {
    return _collection
        .where('opportunityId', isEqualTo: opportunityId)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return Submission.fromMap(doc.id, doc.data());
        });
  }

  Future<String> create(Submission submission) async {
    final ref = await _collection.add(submission.toMap());
    return ref.id;
  }

  Future<void> update(Submission submission) {
    return _collection.doc(submission.id).set(submission.toMap());
  }

  Future<void> updateStatus(String id, SubmissionStatus status) {
    return _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
      if (status == SubmissionStatus.submitted) 'submittedAt': Timestamp.now(),
      if (status.isClosed) 'outcomeAt': Timestamp.now(),
    });
  }

  Future<void> updateAssignedTo(String id, String? assignedTo) {
    return _collection.doc(id).update({
      'assignedTo': assignedTo,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
