import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/project_risk.dart';

class ProjectRiskService {
  ProjectRiskService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projectRisks');

  Stream<List<ProjectRisk>> watchByProjectId(String projectId) {
    return _collection
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ProjectRisk.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> create(ProjectRisk risk) {
    return _collection.add(risk.toMap());
  }

  Future<void> update(ProjectRisk risk) {
    return _collection.doc(risk.id).set(risk.toMap());
  }

  Future<void> updateStatus(String id, RiskStatus status) {
    return _collection.doc(id).update({
      'status': status.name,
      'resolvedAt': status == RiskStatus.closed ? Timestamp.now() : null,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
