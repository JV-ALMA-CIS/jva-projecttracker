import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/library_document.dart';

void main() {
  final now = DateTime.utc(2024, 6, 1);

  test('toMap/fromMap round-trips every field', () {
    final document = LibraryDocument(
      id: 'doc-1',
      title: 'ISO 9001 Certificate',
      category: DocumentCategory.isoCertificate,
      description: 'Quality management certification',
      version: '2024',
      status: DocumentStatus.pendingReview,
      issueDate: now,
      expiryDate: now.add(const Duration(days: 365)),
      owner: 'Quality Team',
      storagePath: 'documents/doc-1/iso.pdf',
      downloadUrl: 'https://example.com/iso.pdf',
      fileName: 'iso.pdf',
      contentType: 'application/pdf',
      fileSizeBytes: 2048,
      businessUnitIds: const ['bu-1'],
      productIds: const ['product-1'],
      serviceIds: const ['service-1'],
      capabilityIds: const ['capability-1'],
      technologyIds: const ['technology-1'],
      industryIds: const ['industry-1'],
      experienceIds: const ['experience-1'],
      knowledgeArticleIds: const ['article-1'],
      relatedProposalIds: const ['proposal-1'],
      projectId: 'project-1',
      aiExtractionStatus: DocumentExtractionStatus.extracted,
      aiExtractedAt: now,
      aiExtractedProjectTitle: 'Rural Water Network',
      aiExtractedClient: 'Ministry of Water',
      aiExtractedFundingAgency: 'USAID',
      aiExtractedCountry: 'Kenya',
      aiExtractedLocation: 'Nairobi',
      aiExtractedContractValueAmount: 250000,
      aiExtractedContractValueCurrency: 'USD',
      aiExtractedContractDuration: '18 months',
      aiExtractedStartDate: now,
      aiExtractedCompletionDate: now.add(const Duration(days: 540)),
      aiExtractedBusinessUnitIds: const ['bu-1'],
      aiExtractedIndustryIds: const ['industry-1'],
      aiExtractedTechnologyIds: const ['technology-1'],
      aiExtractedServiceIds: const ['service-1'],
      aiExtractedCapabilityIds: const ['capability-1'],
      aiExtractedProductIds: const ['product-1'],
      aiExtractedTeamDisciplines: const ['Structural Engineer'],
      aiExtractedDeliverables: const ['Design report'],
      aiExtractedEquipment: const ['Excavator'],
      aiExtractedRisks: const ['Seasonal flooding'],
      aiExtractedSuccessFactors: const ['Strong local partnership'],
      aiExtractedLessonsLearned: const ['Engage community early'],
      aiExtractedCertifications: const ['ISO 9001'],
      aiExtractedStandards: const ['ISO 24512'],
      aiExtractedKeyAchievements: const ['Delivered ahead of schedule'],
      createdAt: now,
      updatedAt: now,
    );

    final restored = LibraryDocument.fromMap('doc-1', document.toMap());

    expect(restored.id, 'doc-1');
    expect(restored.title, 'ISO 9001 Certificate');
    expect(restored.category, DocumentCategory.isoCertificate);
    expect(restored.description, 'Quality management certification');
    expect(restored.version, '2024');
    expect(restored.status, DocumentStatus.pendingReview);
    expect(restored.issueDate?.toUtc(), now.toUtc());
    expect(
      restored.expiryDate?.toUtc(),
      now.add(const Duration(days: 365)).toUtc(),
    );
    expect(restored.owner, 'Quality Team');
    expect(restored.storagePath, 'documents/doc-1/iso.pdf');
    expect(restored.downloadUrl, 'https://example.com/iso.pdf');
    expect(restored.fileName, 'iso.pdf');
    expect(restored.contentType, 'application/pdf');
    expect(restored.fileSizeBytes, 2048);
    expect(restored.businessUnitIds, ['bu-1']);
    expect(restored.productIds, ['product-1']);
    expect(restored.serviceIds, ['service-1']);
    expect(restored.capabilityIds, ['capability-1']);
    expect(restored.technologyIds, ['technology-1']);
    expect(restored.industryIds, ['industry-1']);
    expect(restored.experienceIds, ['experience-1']);
    expect(restored.knowledgeArticleIds, ['article-1']);
    expect(restored.relatedProposalIds, ['proposal-1']);
    expect(restored.createdAt.toUtc(), now.toUtc());
    expect(restored.updatedAt.toUtc(), now.toUtc());
    expect(restored.projectId, 'project-1');
    expect(restored.aiExtractionStatus, DocumentExtractionStatus.extracted);
    expect(restored.aiExtractedAt?.toUtc(), now.toUtc());
    expect(restored.aiExtractedProjectTitle, 'Rural Water Network');
    expect(restored.aiExtractedClient, 'Ministry of Water');
    expect(restored.aiExtractedFundingAgency, 'USAID');
    expect(restored.aiExtractedCountry, 'Kenya');
    expect(restored.aiExtractedLocation, 'Nairobi');
    expect(restored.aiExtractedContractValueAmount, 250000);
    expect(restored.aiExtractedContractValueCurrency, 'USD');
    expect(restored.aiExtractedContractDuration, '18 months');
    expect(restored.aiExtractedStartDate?.toUtc(), now.toUtc());
    expect(
      restored.aiExtractedCompletionDate?.toUtc(),
      now.add(const Duration(days: 540)).toUtc(),
    );
    expect(restored.aiExtractedBusinessUnitIds, ['bu-1']);
    expect(restored.aiExtractedIndustryIds, ['industry-1']);
    expect(restored.aiExtractedTechnologyIds, ['technology-1']);
    expect(restored.aiExtractedServiceIds, ['service-1']);
    expect(restored.aiExtractedCapabilityIds, ['capability-1']);
    expect(restored.aiExtractedProductIds, ['product-1']);
    expect(restored.aiExtractedTeamDisciplines, ['Structural Engineer']);
    expect(restored.aiExtractedDeliverables, ['Design report']);
    expect(restored.aiExtractedEquipment, ['Excavator']);
    expect(restored.aiExtractedRisks, ['Seasonal flooding']);
    expect(restored.aiExtractedSuccessFactors, ['Strong local partnership']);
    expect(restored.aiExtractedLessonsLearned, ['Engage community early']);
    expect(restored.aiExtractedCertifications, ['ISO 9001']);
    expect(restored.aiExtractedStandards, ['ISO 24512']);
    expect(restored.aiExtractedKeyAchievements, [
      'Delivered ahead of schedule',
    ]);
  });

  test('copyWithExtractionStatus updates only the status (+ updatedAt)', () {
    final document = LibraryDocument(
      id: 'doc-3',
      title: 'Award letter',
      category: DocumentCategory.previousProjectEvidence,
      projectId: 'project-1',
      aiExtractionStatus: DocumentExtractionStatus.extracted,
      aiExtractedClient: 'Ministry of Water',
      createdAt: now,
      updatedAt: now,
    );

    final reviewed = document.copyWithExtractionStatus(
      DocumentExtractionStatus.reviewed,
    );

    expect(reviewed.aiExtractionStatus, DocumentExtractionStatus.reviewed);
    expect(reviewed.aiExtractedClient, 'Ministry of Water');
    expect(reviewed.projectId, 'project-1');
  });

  test('fromMap defaults missing fields safely', () {
    final restored = LibraryDocument.fromMap('doc-2', {
      'title': 'Untitled',
      'category': 'other',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.description, '');
    expect(restored.version, '');
    expect(restored.status, DocumentStatus.active);
    expect(restored.issueDate, isNull);
    expect(restored.expiryDate, isNull);
    expect(restored.owner, isNull);
    expect(restored.storagePath, isNull);
    expect(restored.businessUnitIds, isEmpty);
    expect(restored.relatedProposalIds, isEmpty);
    expect(restored.projectId, isNull);
    expect(restored.aiExtractionStatus, DocumentExtractionStatus.none);
    expect(restored.aiExtractedAt, isNull);
    expect(restored.aiExtractedBusinessUnitIds, isEmpty);
    expect(restored.aiExtractedTeamDisciplines, isEmpty);
  });

  test(
    'DocumentExtractionStatusX.fromString falls back to none for unknown values',
    () {
      expect(
        DocumentExtractionStatusX.fromString('not-a-real-status'),
        DocumentExtractionStatus.none,
      );
    },
  );

  test(
    'DocumentCategoryX.fromString falls back to other for unknown values',
    () {
      expect(
        DocumentCategoryX.fromString('not-a-real-category'),
        DocumentCategory.other,
      );
    },
  );

  test(
    'DocumentStatusX.fromString falls back to active for unknown values',
    () {
      expect(
        DocumentStatusX.fromString('not-a-real-status'),
        DocumentStatus.active,
      );
    },
  );
}
