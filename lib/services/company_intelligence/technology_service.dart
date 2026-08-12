import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';

class TechnologyService {
  TechnologyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('technologies');

  Stream<List<Technology>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Technology.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Technology?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Technology.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(Technology technology) async {
    final doc = await _collection.add(technology.toMap());
    return doc.id;
  }

  Future<void> update(Technology technology) {
    return _collection.doc(technology.id).update(technology.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
