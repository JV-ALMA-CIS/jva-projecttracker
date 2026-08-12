import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';

const kProposalsCollection = 'proposals';

/// Read/write access to the `proposals` collection — one document per
/// opportunity by convention. Section content lives in
/// `ProposalSectionService`, a separate collection.
class ProposalService {
  ProposalService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kProposalsCollection);

  /// The proposal for [opportunityId], or `null` if one hasn't been
  /// created yet. A single equality filter needs no composite index.
  Stream<Proposal?> watchByOpportunityId(String opportunityId) {
    return _collection
        .where('opportunityId', isEqualTo: opportunityId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : Proposal.fromMap(
                  snapshot.docs.first.id,
                  snapshot.docs.first.data(),
                ),
        );
  }

  /// Every proposal, most-recently-updated first — for a Dashboard-level
  /// "active proposals" view. Same `orderBy('updatedAt', descending: true)`
  /// convention every other `watchAll()` in this codebase uses.
  Stream<List<Proposal>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Proposal.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(Proposal proposal) async {
    final doc = await _collection.add(proposal.toMap());
    return doc.id;
  }

  Future<void> updateTitle(String id, String title) {
    return _collection.doc(id).update({
      'title': title,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Also stamps/clears `readyForReviewAt`: set to now when transitioning
  /// to [ProposalStatus.readyForReview], cleared on reopen to
  /// [ProposalStatus.draft] — so the Proposal Workspace's Timeline section
  /// can show exactly when a proposal was last marked ready, without a new
  /// method or a separate event collection. Transitioning to
  /// [ProposalStatus.finalized] leaves `readyForReviewAt` untouched (the key
  /// is simply omitted) — finalizing always happens *from*
  /// `readyForReview`, and the Submission Timeline needs that timestamp to
  /// keep meaning "when this proposal was marked ready" even after submission.
  Future<void> updateStatus(String id, ProposalStatus status) {
    final update = <String, dynamic>{
      'status': status.name,
      'updatedAt': Timestamp.now(),
    };
    if (status == ProposalStatus.readyForReview) {
      update['readyForReviewAt'] = Timestamp.now();
    } else if (status == ProposalStatus.draft) {
      update['readyForReviewAt'] = null;
    }
    return _collection.doc(id).update(update);
  }

  Future<void> updateAssignedTo(String id, String? assignedTo) {
    return _collection.doc(id).update({
      'assignedTo': assignedTo,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Whole-list overwrite of internal sign-off decisions (Milestone 4.4) —
  /// mirrors `updateAssignedTo`'s narrow-setter shape. Callers compute the
  /// new list via `applyApprovalDecision` (pure, in `proposal_approval.dart`)
  /// before calling this.
  Future<void> updateApprovals(String id, List<ProposalApproval> approvals) {
    return _collection.doc(id).update({
      'approvals': approvals.map((a) => a.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
