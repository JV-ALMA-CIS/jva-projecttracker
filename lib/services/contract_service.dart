import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/models/contract.dart';

class ContractService {
  ContractService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('contracts');

  Stream<List<Contract>> watchAll() {
    return _collection
        .orderBy('fitScorePercent', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Contract.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Contract>> watchByStatus(ContractStatus status) {
    return _collection
        .where('status', isEqualTo: status.name)
        .orderBy('fitScorePercent', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Contract.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> updateStatus(String id, ContractStatus status) {
    return _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  /// Triggers the `searchContracts` callable Cloud Function, which runs a web
  /// search for new opportunities and scores each one against the company's
  /// project/application history via Gemini. Results are written to Firestore
  /// by the function itself.
  Future<int> triggerDiscoveryRun({String? query}) async {
    final callable = _functions.httpsCallable('searchContracts');
    final result = await callable.call<Map<String, dynamic>>({'query': query});
    return (result.data['created'] as num?)?.toInt() ?? 0;
  }
}
