import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';

class CertificationService {
  CertificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('certifications');

  Stream<List<Certification>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Certification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Certification?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? Certification.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(Certification certification) async {
    final doc = await _collection.add(certification.toMap());
    return doc.id;
  }

  Future<void> update(Certification certification) {
    return _collection.doc(certification.id).update(certification.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
