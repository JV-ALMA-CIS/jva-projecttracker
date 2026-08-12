import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/services/document_suggestions.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

void main() {
  final now = DateTime.utc(2024, 6, 15);

  Opportunity opportunity({
    List<String> technologyIds = const [],
    List<String> experienceIds = const [],
    List<String> industryIds = const [],
  }) {
    return Opportunity(
      id: 'opp-1',
      title: 'Road tender',
      description: '',
      sourceUrl: 'https://example.com/1',
      discoveredAt: now,
      updatedAt: now,
      technologyIds: technologyIds,
      experienceIds: experienceIds,
      industryIds: industryIds,
    );
  }

  final proposal = Proposal(
    id: 'proposal-1',
    opportunityId: 'opp-1',
    title: 'Road tender proposal',
    createdAt: now,
    updatedAt: now,
  );

  LibraryDocument doc({
    required String id,
    DocumentCategory category = DocumentCategory.other,
    DocumentStatus status = DocumentStatus.active,
    DateTime? expiryDate,
    List<String> technologyIds = const [],
    List<String> experienceIds = const [],
    List<String> industryIds = const [],
    List<String> relatedProposalIds = const [],
  }) {
    return LibraryDocument(
      id: id,
      title: id,
      category: category,
      status: status,
      expiryDate: expiryDate,
      technologyIds: technologyIds,
      experienceIds: experienceIds,
      industryIds: industryIds,
      relatedProposalIds: relatedProposalIds,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('flags every required category missing from linked documents', () {
    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(),
      proposal: proposal,
      allDocuments: const [],
      linkedDocuments: const [],
      now: now,
    );

    final missing = suggestions
        .where(
          (s) =>
              s.category == DocumentSuggestionCategory.missingMandatoryDocument,
        )
        .map((s) => s.missingCategory)
        .toSet();
    expect(missing, kRequiredDocumentCategories);
  });

  test('does not flag a required category already linked and unexpired', () {
    final linked = [
      for (final category in kRequiredDocumentCategories)
        doc(id: category.name, category: category),
    ];

    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(),
      proposal: proposal,
      allDocuments: linked,
      linkedDocuments: linked,
      now: now,
    );

    expect(
      suggestions.where(
        (s) =>
            s.category == DocumentSuggestionCategory.missingMandatoryDocument,
      ),
      isEmpty,
    );
  });

  test('flags a linked document expiring within the warning window', () {
    final expiringSoon = doc(
      id: 'insurance-cert',
      category: DocumentCategory.insurance,
      expiryDate: now.add(const Duration(days: 10)),
    );

    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(),
      proposal: proposal,
      allDocuments: [expiringSoon],
      linkedDocuments: [expiringSoon],
      now: now,
    );

    final expiring = suggestions.where(
      (s) => s.category == DocumentSuggestionCategory.expiringCertificate,
    );
    expect(expiring, hasLength(1));
    expect(expiring.single.documentTitle, 'insurance-cert');
    expect(expiring.single.daysUntilExpiry, 10);
  });

  test('does not flag a document expiring well beyond the warning window', () {
    final farFromExpiry = doc(
      id: 'insurance-cert',
      category: DocumentCategory.insurance,
      expiryDate: now.add(const Duration(days: 300)),
    );

    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(),
      proposal: proposal,
      allDocuments: [farFromExpiry],
      linkedDocuments: [farFromExpiry],
      now: now,
    );

    expect(
      suggestions.where(
        (s) => s.category == DocumentSuggestionCategory.expiringCertificate,
      ),
      isEmpty,
    );
  });

  test('suggests a relevant technical brochure matching the opportunity', () {
    final brochure = doc(
      id: 'flutter-brochure',
      category: DocumentCategory.technicalBrochure,
      technologyIds: const ['tech-1'],
    );

    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(technologyIds: const ['tech-1']),
      proposal: proposal,
      allDocuments: [brochure],
      linkedDocuments: const [],
      now: now,
    );

    final relevant = suggestions.where(
      (s) => s.category == DocumentSuggestionCategory.relevantTechnicalBrochure,
    );
    expect(relevant, hasLength(1));
    expect(relevant.single.documentTitle, 'flutter-brochure');
  });

  test(
    'suggests a recommended experience document matching the opportunity',
    () {
      final evidence = doc(
        id: 'road-project-evidence',
        category: DocumentCategory.previousProjectEvidence,
        experienceIds: const ['experience-1'],
      );

      final suggestions = deriveDocumentSuggestions(
        opportunity: opportunity(experienceIds: const ['experience-1']),
        proposal: proposal,
        allDocuments: [evidence],
        linkedDocuments: const [],
        now: now,
      );

      final recommended = suggestions.where(
        (s) =>
            s.category ==
            DocumentSuggestionCategory.recommendedExperienceDocument,
      );
      expect(recommended, hasLength(1));
      expect(recommended.single.documentTitle, 'road-project-evidence');
    },
  );

  test(
    'suggests a similar previous proposal document sharing an industry, but not one already linked here',
    () {
      final similar = doc(
        id: 'similar-proposal-doc',
        industryIds: const ['industry-1'],
        relatedProposalIds: const ['other-proposal'],
      );
      final alreadyLinked = doc(
        id: 'already-linked-doc',
        industryIds: const ['industry-1'],
        relatedProposalIds: const ['proposal-1'],
      );

      final suggestions = deriveDocumentSuggestions(
        opportunity: opportunity(industryIds: const ['industry-1']),
        proposal: proposal,
        allDocuments: [similar, alreadyLinked],
        linkedDocuments: const [],
        now: now,
      );

      final matches = suggestions.where(
        (s) => s.category == DocumentSuggestionCategory.similarPreviousProposal,
      );
      expect(matches, hasLength(1));
      expect(matches.single.documentTitle, 'similar-proposal-doc');
    },
  );

  test('caps the number of suggestions at 8', () {
    final documents = [
      for (var i = 0; i < 10; i++)
        doc(
          id: 'brochure-$i',
          category: DocumentCategory.technicalBrochure,
          technologyIds: const ['tech-1'],
        ),
    ];

    final suggestions = deriveDocumentSuggestions(
      opportunity: opportunity(technologyIds: const ['tech-1']),
      proposal: proposal,
      allDocuments: documents,
      linkedDocuments: const [],
      now: now,
    );

    expect(suggestions, hasLength(8));
  });
}
