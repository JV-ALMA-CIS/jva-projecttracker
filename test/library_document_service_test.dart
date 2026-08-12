import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LibraryDocumentService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = LibraryDocumentService(firestore: firestore);
  });

  LibraryDocument buildDocument({
    required String title,
    DocumentCategory category = DocumentCategory.other,
    List<String> relatedProposalIds = const [],
    String? projectId,
  }) {
    final now = DateTime.utc(2024, 6, 1);
    return LibraryDocument(
      id: '',
      title: title,
      category: category,
      relatedProposalIds: relatedProposalIds,
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a document that watchAll then returns', () async {
    await service.create(buildDocument(title: 'Company Registration'));

    final documents = await service.watchAll().first;
    expect(documents, hasLength(1));
    expect(documents.single.title, 'Company Registration');
  });

  test('watchById returns null for a missing document', () async {
    final document = await service.watchById('missing').first;
    expect(document, isNull);
  });

  test(
    'watchByProposal only returns documents linked to that proposal',
    () async {
      await service.create(
        buildDocument(
          title: 'Linked to proposal-1',
          relatedProposalIds: const ['proposal-1'],
        ),
      );
      await service.create(
        buildDocument(
          title: 'Linked to proposal-2',
          relatedProposalIds: const ['proposal-2'],
        ),
      );

      final documents = await service.watchByProposal('proposal-1').first;
      expect(documents, hasLength(1));
      expect(documents.single.title, 'Linked to proposal-1');
    },
  );

  test(
    'watchByProject only returns documents uploaded for that project',
    () async {
      await service.create(
        buildDocument(title: 'Award letter', projectId: 'project-1'),
      );
      await service.create(
        buildDocument(title: 'Other project doc', projectId: 'project-2'),
      );

      final documents = await service.watchByProject('project-1').first;
      expect(documents, hasLength(1));
      expect(documents.single.title, 'Award letter');
    },
  );

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildDocument(title: 'Original title'));
    final original = await service.watchById(id).first;

    await service.update(
      LibraryDocument(
        id: id,
        title: 'Updated title',
        category: DocumentCategory.license,
        createdAt: original!.createdAt,
        updatedAt: DateTime.utc(2024, 6, 2),
      ),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.title, 'Updated title');
    expect(updated.category, DocumentCategory.license);
  });

  test('delete removes the document', () async {
    final id = await service.create(buildDocument(title: 'Delete me'));

    await service.delete(id);

    final document = await service.watchById(id).first;
    expect(document, isNull);
  });
}
