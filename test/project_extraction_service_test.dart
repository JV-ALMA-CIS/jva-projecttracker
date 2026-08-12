import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/project_extraction_service.dart';

void main() {
  test(
    'extract forwards the requested documentId to the invoke callback',
    () async {
      String? seenDocumentId;
      final service = ProjectExtractionService(
        invokeOverride: ({required documentId}) async {
          seenDocumentId = documentId;
        },
      );

      await service.extract(documentId: 'document-42');

      expect(seenDocumentId, 'document-42');
    },
  );

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as ProjectExtractionException',
    () async {
      final service = ProjectExtractionService(
        invokeOverride: ({required documentId}) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.extract(documentId: 'document-1'),
        throwsA(
          isA<ProjectExtractionException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );

  test(
    'extract completes normally when the invoke callback succeeds',
    () async {
      final service = ProjectExtractionService(
        invokeOverride: ({required documentId}) async {},
      );

      await expectLater(service.extract(documentId: 'document-1'), completes);
    },
  );
}
