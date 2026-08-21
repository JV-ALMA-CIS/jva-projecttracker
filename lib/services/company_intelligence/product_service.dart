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

  /// Merges two live queries client-side: the legacy single-field
  /// `businessUnitId` equality query (still written on every save as the
  /// first entry of `businessUnitIds` — see [Product.toMap]) and a new
  /// `businessUnitIds` `array-contains` query, so a product belonging to
  /// this BU as its 2nd/3rd membership (not just its first) is still found.
  /// Both are single-field filters — neither needs a new composite index.
  Stream<List<Product>> watchByBusinessUnit(String businessUnitId) {
    final legacy = _collection.where(
      'businessUnitId',
      isEqualTo: businessUnitId,
    );
    final canonical = _collection.where(
      'businessUnitIds',
      arrayContains: businessUnitId,
    );

    return legacy.snapshots().asyncMap((legacySnapshot) async {
      final canonicalSnapshot = await canonical.get();
      final byId = <String, Product>{};
      for (final doc in legacySnapshot.docs) {
        byId[doc.id] = Product.fromMap(doc.id, doc.data());
      }
      for (final doc in canonicalSnapshot.docs) {
        byId[doc.id] = Product.fromMap(doc.id, doc.data());
      }
      final products = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return products;
    });
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
