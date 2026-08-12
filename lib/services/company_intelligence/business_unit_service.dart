import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';

class BusinessUnitService {
  BusinessUnitService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('businessUnits');

  Stream<List<BusinessUnit>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessUnit.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<BusinessUnit>> watchByStatus(BusinessUnitStatus status) {
    return _collection
        .where('status', isEqualTo: status.name)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessUnit.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<BusinessUnit?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? BusinessUnit.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(BusinessUnit businessUnit) async {
    final doc = await _collection.add(businessUnit.toMap());
    return doc.id;
  }

  Future<void> update(BusinessUnit businessUnit) {
    return _collection.doc(businessUnit.id).update(businessUnit.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
