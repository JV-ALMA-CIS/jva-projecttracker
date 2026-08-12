import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/project_deliverable.dart';

class ProjectDeliverableService {
  ProjectDeliverableService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projectDeliverables');

  Stream<List<ProjectDeliverable>> watchByProjectId(String projectId) {
    return _collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ProjectDeliverable.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> create(ProjectDeliverable deliverable) {
    return _collection.add(deliverable.toMap());
  }

  Future<void> update(ProjectDeliverable deliverable) {
    return _collection.doc(deliverable.id).set(deliverable.toMap());
  }

  Future<void> updateStatus(
    String id,
    ProjectDeliverableStatus status, {
    String? blockedReason,
  }) {
    return _collection.doc(id).update({
      'status': status.name,
      'blockedReason': status == ProjectDeliverableStatus.blocked
          ? blockedReason
          : null,
      'completedAt': status == ProjectDeliverableStatus.completed
          ? Timestamp.now()
          : null,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
