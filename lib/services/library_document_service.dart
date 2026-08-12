import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:jva_projecttracker/models/library_document.dart';

const kLibraryDocumentsCollection = 'documents';

/// Where one document's binary lives in Firebase Storage — Firestore only
/// ever stores this path plus the resolved download URL, never the file
/// itself. See the Document Library (Milestone 4.3).
String libraryDocumentStoragePath(String documentId, String fileName) =>
    'documents/$documentId/$fileName';

/// Read/write access to the `documents` collection (metadata) and the
/// matching Firebase Storage objects (binaries). Mirrors `KnowledgeService`
/// for the Firestore half exactly; the Storage half is a thin wrapper with
/// no automated test coverage (no fake Storage package in this app, no live
/// Firebase project configured — see Decision 10 in the milestone plan).
class LibraryDocumentService {
  LibraryDocumentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageOverride = storage;

  final FirebaseFirestore _firestore;

  // Resolved lazily — constructing this with only a fake Firestore (every
  // metadata-only test in this app) must not require Firebase Core to be
  // initialized just to reach FirebaseStorage.instance.
  final FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kLibraryDocumentsCollection);

  Stream<List<LibraryDocument>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LibraryDocument.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<LibraryDocument?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? LibraryDocument.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Every document linked to [proposalId]. A single array-contains filter
  /// needs no composite index.
  Stream<List<LibraryDocument>> watchByProposal(String proposalId) {
    return _collection
        .where('relatedProposalIds', arrayContains: proposalId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LibraryDocument.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Every document uploaded for [projectId] (AI Knowledge Extraction). A
  /// single equality filter needs no composite index — mirrors
  /// [watchByProposal].
  Stream<List<LibraryDocument>> watchByProject(String projectId) {
    return _collection
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LibraryDocument.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(LibraryDocument document) async {
    final doc = await _collection.add(document.toMap());
    return doc.id;
  }

  Future<void> update(LibraryDocument document) {
    return _collection.doc(document.id).update(document.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  /// Uploads [bytes] to Storage at `documents/{documentId}/{fileName}` and
  /// returns its resolved download URL. Callers are expected to then write
  /// `storagePath`/`downloadUrl`/`fileName`/`contentType`/`fileSizeBytes`
  /// onto the corresponding [LibraryDocument] via [update].
  Future<String> uploadFile({
    required String documentId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final path = libraryDocumentStoragePath(documentId, fileName);
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> deleteFile(String storagePath) {
    return _storage.ref(storagePath).delete();
  }
}
