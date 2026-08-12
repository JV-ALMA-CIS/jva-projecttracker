import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/discovery_source.dart';

const kDiscoverySourcesCollection = 'discoverySources';

/// Read/write access to the `discoverySources` collection — configured
/// external opportunity sources. See the Opportunity Discovery Engine
/// (Milestone 3.7).
class DiscoverySourceService {
  DiscoverySourceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kDiscoverySourcesCollection);

  Stream<List<DiscoverySource>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DiscoverySource.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<DiscoverySource?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? DiscoverySource.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(DiscoverySource source) async {
    final doc = await _collection.add(source.toMap());
    return doc.id;
  }

  Future<void> update(DiscoverySource source) {
    return _collection.doc(source.id).update(source.toMap());
  }

  /// Narrow toggle-only update — mirrors `RecommendationService.dismiss`.
  Future<void> setEnabled(String id, bool enabled) {
    return _collection.doc(id).update({
      'enabled': enabled,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
