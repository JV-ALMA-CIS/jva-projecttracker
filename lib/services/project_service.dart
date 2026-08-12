import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/project.dart';

class ProjectService {
  ProjectService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projects');

  Stream<List<Project>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Project.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Project>> watchByStatus(ProjectStatus status) {
    return _collection
        .where('status', isEqualTo: status.name)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Project.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Project?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Project.fromMap(doc.id, doc.data()!) : null);
  }

  /// The project started from [opportunityId], or `null` if none has been
  /// created yet. A single equality filter needs no composite index.
  /// Mirrors `ProposalService.watchByOpportunityId` exactly.
  Stream<Project?> watchByOpportunityId(String opportunityId) {
    return _collection
        .where('sourceOpportunityId', isEqualTo: opportunityId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : Project.fromMap(
                  snapshot.docs.first.id,
                  snapshot.docs.first.data(),
                ),
        );
  }

  Future<Project?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Project.fromMap(doc.id, doc.data()!);
  }

  /// Creates a project and returns the new Firestore document id.
  /// [Project.id] on the input is ignored — the generated doc id is the
  /// source of truth (same pattern as LibraryDocumentService.create).
  Future<String> create(Project project) async {
    final doc = _collection.doc();
    await doc.set(project.toMap());
    return doc.id;
  }

  Future<void> update(Project project) {
    return _collection.doc(project.id).update(project.toMap());
  }

  /// Records which `Experience` was created from this completed project —
  /// a narrow setter (mirrors `ProposalService.updateAssignedTo`) so
  /// "promote to Experience" doesn't need to round-trip the whole `Project`
  /// through `copyWith`.
  Future<void> linkExperience(String projectId, String experienceId) {
    return _collection.doc(projectId).update({
      'experienceId': experienceId,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
