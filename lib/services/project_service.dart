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

  Future<Project?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Project.fromMap(doc.id, doc.data()!);
  }

  Future<String> create(Project project) async {
    final doc = await _collection.add(project.toMap());
    return doc.id;
  }

  Future<void> update(Project project) {
    return _collection.doc(project.id).update(project.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
