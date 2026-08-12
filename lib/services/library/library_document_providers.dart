import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';

final libraryDocumentServiceProvider = Provider(
  (ref) => LibraryDocumentService(),
);

final libraryDocumentsStreamProvider = StreamProvider<List<LibraryDocument>>((
  ref,
) {
  return ref.watch(libraryDocumentServiceProvider).watchAll();
});

/// A single library document by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final libraryDocumentByIdProvider = StreamProvider.autoDispose
    .family<LibraryDocument?, String>((ref, id) {
      return ref.watch(libraryDocumentServiceProvider).watchById(id);
    });

/// Every document uploaded for one project (AI Knowledge Extraction), live.
final documentsForProjectProvider =
    StreamProvider.family<List<LibraryDocument>, String>((ref, projectId) {
      return ref
          .watch(libraryDocumentServiceProvider)
          .watchByProject(projectId);
    });
