import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';

class ExperienceService {
  ExperienceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('experiences');

  Stream<List<Experience>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Experience.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Experience?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Experience.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(Experience experience) async {
    final doc = await _collection.add(experience.toMap());
    return doc.id;
  }

  Future<void> update(Experience experience) {
    return _collection.doc(experience.id).update(experience.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
