import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

/// CRUD + live-stream access to the `tenderSources` collection. Firestore
/// access is injected (defaults to [FirebaseFirestore.instance]) so tests
/// can substitute a fake/mock instance without touching a real project —
/// see test/services/tender_source_service_test.dart.
class TenderSourceService {
  TenderSourceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tenderSources');

  Stream<List<TenderSource>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TenderSource.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<TenderSource?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (snap) =>
              snap.exists ? TenderSource.fromMap(snap.id, snap.data()!) : null,
        );
  }

  Future<String> create(TenderSource source) async {
    final now = DateTime.now();
    final data = source.copyWith(updatedAt: now).toMap();
    data['createdAt'] = Timestamp.fromDate(now);
    final ref = await _collection.add(data);
    return ref.id;
  }

  Future<void> update(TenderSource source) async {
    await _collection
        .doc(source.id)
        .update(source.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _collection.doc(id).update({
      'enabled': enabled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> pause(String id) => _setStatus(id, TenderSourceStatus.paused);

  Future<void> resume(String id) => _setStatus(id, TenderSourceStatus.active);

  Future<void> _setStatus(String id, TenderSourceStatus status) async {
    await _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}
