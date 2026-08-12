import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';

class ServiceService {
  ServiceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('services');

  Stream<List<ServiceModel>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ServiceModel>> watchByBusinessUnit(String businessUnitId) {
    return _collection
        .where('businessUnitIds', arrayContains: businessUnitId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<ServiceModel?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? ServiceModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(ServiceModel service) async {
    final doc = await _collection.add(service.toMap());
    return doc.id;
  }

  Future<void> update(ServiceModel service) {
    return _collection.doc(service.id).update(service.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
