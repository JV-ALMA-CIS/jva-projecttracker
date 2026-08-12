import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';

class CapabilityService {
  CapabilityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('capabilities');

  Stream<List<Capability>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Capability.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Capability?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Capability.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(Capability capability) async {
    final doc = await _collection.add(capability.toMap());
    return doc.id;
  }

  Future<void> update(Capability capability) {
    return _collection.doc(capability.id).update(capability.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
