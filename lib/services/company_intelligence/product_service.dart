import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('products');

  Stream<List<Product>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Product>> watchByBusinessUnit(String businessUnitId) {
    return _collection
        .where('businessUnitId', isEqualTo: businessUnitId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Product?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Product.fromMap(doc.id, doc.data()!) : null);
  }

  Future<String> create(Product product) async {
    final doc = await _collection.add(product.toMap());
    return doc.id;
  }

  Future<void> update(Product product) {
    return _collection.doc(product.id).update(product.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
