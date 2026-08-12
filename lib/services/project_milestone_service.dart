import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/project_milestone.dart';

class ProjectMilestoneService {
  ProjectMilestoneService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projectMilestones');

  Stream<List<ProjectMilestone>> watchByProjectId(String projectId) {
    return _collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ProjectMilestone.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> create(ProjectMilestone milestone) {
    return _collection.add(milestone.toMap());
  }

  Future<void> update(ProjectMilestone milestone) {
    return _collection.doc(milestone.id).set(milestone.toMap());
  }

  Future<void> markCompleted(String id, {bool completed = true}) {
    return _collection.doc(id).update({
      'completedAt': completed ? Timestamp.now() : null,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
