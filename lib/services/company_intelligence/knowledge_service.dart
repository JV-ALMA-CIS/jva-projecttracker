import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';

class KnowledgeService {
  KnowledgeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('knowledgeBase');

  Stream<List<KnowledgeArticle>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => KnowledgeArticle.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<KnowledgeArticle?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? KnowledgeArticle.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<String> create(KnowledgeArticle article) async {
    final doc = await _collection.add(article.toMap());
    return doc.id;
  }

  Future<void> update(KnowledgeArticle article) {
    return _collection.doc(article.id).update(article.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
