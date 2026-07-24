import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/application.dart';

class ApplicationService {
  ApplicationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('applications');

  Stream<List<CompanyApplication>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CompanyApplication.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<CompanyApplication?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? CompanyApplication.fromMap(doc.id, doc.data()!)
              : null,
        );
  }

  Future<CompanyApplication?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return CompanyApplication.fromMap(doc.id, doc.data()!);
  }

  Future<String> create(CompanyApplication application) async {
    final doc = await _collection.add(application.toMap());
    return doc.id;
  }

  Future<void> update(CompanyApplication application) {
    return _collection.doc(application.id).update(application.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
