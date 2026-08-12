import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';

const kProposalSectionsCollection = 'proposalSections';

/// Read/write access to the `proposalSections` collection — every section
/// belonging to a [Proposal], ordered by [ProposalSection.order].
class ProposalSectionService {
  ProposalSectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kProposalSectionsCollection);

  Stream<List<ProposalSection>> watchByProposalId(String proposalId) {
    return _collection
        .where('proposalId', isEqualTo: proposalId)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProposalSection.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(ProposalSection section) async {
    final doc = await _collection.add(section.toMap());
    return doc.id;
  }

  /// A human edit to a section's content — always sets `status: edited`,
  /// since a section a person has typed into is no longer "not started"
  /// (and, ahead of Milestone 4.2, is what distinguishes a human edit from
  /// an AI-drafted one).
  Future<void> updateContent(String id, String content) {
    return _collection.doc(id).update({
      'content': content,
      'status': ProposalSectionStatus.edited.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateTitle(String id, String title) {
    return _collection.doc(id).update({
      'title': title,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateStatus(String id, ProposalSectionStatus status) {
    return _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateAssignedTo(String id, String? assignedTo) {
    return _collection.doc(id).update({
      'assignedTo': assignedTo,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Restores [section]'s single-slot undo buffer — swaps `previousContent`/
  /// `previousStatus` back into `content`/`status` and clears the slot. A
  /// no-op if there's nothing to restore (`previousContent == null`), so
  /// callers don't need to guard this themselves.
  Future<void> restorePreviousVersion(ProposalSection section) {
    if (section.previousContent == null) return Future.value();
    return _collection.doc(section.id).update({
      'content': section.previousContent,
      'status': (section.previousStatus ?? ProposalSectionStatus.edited).name,
      'previousContent': null,
      'previousStatus': null,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Persists a new section order after a drag-to-reorder — one batched
  /// write across every affected document, same shape as
  /// `OpportunityService.transitionStage`'s batch.
  Future<void> reorder(List<String> orderedSectionIds) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    for (final (index, id) in orderedSectionIds.indexed) {
      batch.update(_collection.doc(id), {'order': index, 'updatedAt': now});
    }
    await batch.commit();
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
