import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';

class IndustryService {
  IndustryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('industries');

  Stream<List<Industry>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Industry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Industry?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Industry.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(Industry industry) async {
    final doc = await _collection.add(industry.toMap());
    return doc.id;
  }

  Future<void> update(Industry industry) {
    return _collection.doc(industry.id).update(industry.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
