import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

void main() {
  final now = DateTime.utc(2024, 6, 15);

  LibraryDocument doc({
    required String id,
    required DocumentCategory category,
    DocumentStatus status = DocumentStatus.active,
    DateTime? expiryDate,
  }) {
    return LibraryDocument(
      id: id,
      title: id,
      category: category,
      status: status,
      expiryDate: expiryDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('is not ready when no documents are linked', () {
    final readiness = deriveSubmissionReadiness(
      proposalDocuments: const [],
      now: now,
    );

    expect(readiness.isReady, isFalse);
    expect(readiness.missingCategories, kRequiredDocumentCategories);
    expect(readiness.uploadedCategories, isEmpty);
  });

  test('is ready when every required category has an active document', () {
    final readiness = deriveSubmissionReadiness(
      proposalDocuments: [
        for (final category in kRequiredDocumentCategories)
          doc(id: category.name, category: category),
      ],
      now: now,
    );

    expect(readiness.isReady, isTrue);
    expect(readiness.missingCategories, isEmpty);
    expect(readiness.uploadedCategories, kRequiredDocumentCategories);
  });

  test('an expired document does not count toward coverage', () {
    final readiness = deriveSubmissionReadiness(
      proposalDocuments: [
        doc(
          id: 'expired-license',
          category: DocumentCategory.license,
          expiryDate: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );

    expect(readiness.missingCategories, contains(DocumentCategory.license));
    expect(readiness.expiredDocuments, hasLength(1));
  });

  test('an archived document does not count toward coverage', () {
    final readiness = deriveSubmissionReadiness(
      proposalDocuments: [
        doc(
          id: 'archived-license',
          category: DocumentCategory.license,
          status: DocumentStatus.archived,
        ),
      ],
      now: now,
    );

    expect(readiness.missingCategories, contains(DocumentCategory.license));
  });

  test('pending-review and needs-update documents are surfaced separately', () {
    final readiness = deriveSubmissionReadiness(
      proposalDocuments: [
        doc(
          id: 'pending',
          category: DocumentCategory.license,
          status: DocumentStatus.pendingReview,
        ),
        doc(
          id: 'stale',
          category: DocumentCategory.insurance,
          status: DocumentStatus.needsUpdate,
        ),
      ],
      now: now,
    );

    expect(readiness.pendingReviewDocuments, hasLength(1));
    expect(readiness.pendingReviewDocuments.single.id, 'pending');
    expect(readiness.needsUpdateDocuments, hasLength(1));
    expect(readiness.needsUpdateDocuments.single.id, 'stale');
    // A pending-review/needs-update document is still active, so it still
    // covers its category — flagged for attention, not treated as missing.
    expect(
      readiness.uploadedCategories,
      containsAll([DocumentCategory.license, DocumentCategory.insurance]),
    );
  });
}
