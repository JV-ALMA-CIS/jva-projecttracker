import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';

void main() {
  test('ProposalSection round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 8, 1);
    final updatedAt = DateTime.utc(2024, 8, 2);

    final section = ProposalSection(
      id: 'section-1',
      proposalId: 'proposal-1',
      order: 2,
      type: ProposalSectionType.technicalApproach,
      title: 'Technical Approach',
      content: 'We propose a phased rollout.',
      status: ProposalSectionStatus.edited,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = section.toMap();
    final restored = ProposalSection.fromMap(section.id, map);

    expect(restored.proposalId, section.proposalId);
    expect(restored.order, 2);
    expect(restored.type, ProposalSectionType.technicalApproach);
    expect(restored.title, section.title);
    expect(restored.content, section.content);
    expect(restored.status, ProposalSectionStatus.edited);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test(
    'ProposalSection defaults content/status/order on a partial document',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = ProposalSection.fromMap('section-2', {
        'proposalId': 'proposal-1',
        'type': 'companyExperience',
        'title': 'Company Experience',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.order, 0);
      expect(restored.content, isEmpty);
      expect(restored.status, ProposalSectionStatus.notStarted);
    },
  );

  test('ProposalSection falls back to custom for an unrecognized type', () {
    final now = DateTime.utc(2024, 8, 1);
    final restored = ProposalSection.fromMap('section-3', {
      'proposalId': 'proposal-1',
      'type': 'somethingNewFromAFutureVersion',
      'title': 'Mystery Section',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.type, ProposalSectionType.custom);
  });

  test('ProposalSection round-trips assignedTo', () {
    final now = DateTime.utc(2024, 8, 1);
    final section = ProposalSection(
      id: 'section-4',
      proposalId: 'proposal-1',
      order: 0,
      type: ProposalSectionType.custom,
      title: 'Custom Section',
      assignedTo: 'jane@example.com',
      createdAt: now,
      updatedAt: now,
    );

    final restored = ProposalSection.fromMap(section.id, section.toMap());

    expect(restored.assignedTo, 'jane@example.com');
  });

  test('ProposalSection defaults assignedTo to null when missing', () {
    final now = DateTime.utc(2024, 8, 1);
    final restored = ProposalSection.fromMap('section-5', {
      'proposalId': 'proposal-1',
      'type': 'custom',
      'title': 'Custom Section',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.assignedTo, isNull);
  });

  test('standardSet contains the 13 Milestone 4.2 section types in order', () {
    expect(ProposalSectionTypeX.standardSet, [
      ProposalSectionType.executiveSummary,
      ProposalSectionType.companyProfile,
      ProposalSectionType.technicalApproach,
      ProposalSectionType.methodology,
      ProposalSectionType.workPlan,
      ProposalSectionType.teamQualifications,
      ProposalSectionType.companyExperience,
      ProposalSectionType.productsAndTechnologies,
      ProposalSectionType.riskManagement,
      ProposalSectionType.sustainability,
      ProposalSectionType.innovation,
      ProposalSectionType.valueProposition,
      ProposalSectionType.conclusion,
    ]);
    expect(
      ProposalSectionTypeX.standardSet.contains(ProposalSectionType.custom),
      isFalse,
    );
    // Pre-4.2 types remain valid, addable types — just no longer part of
    // the default scaffold.
    expect(
      ProposalSectionTypeX.standardSet.contains(
        ProposalSectionType.understandingOfRequirements,
      ),
      isFalse,
    );
    expect(
      ProposalSectionTypeX.standardSet.contains(
        ProposalSectionType.pricingApproach,
      ),
      isFalse,
    );
  });

  test('ProposalSection round-trips AI generation fields', () {
    final now = DateTime.utc(2024, 8, 1);
    final generatedAt = DateTime.utc(2024, 8, 3);

    final section = ProposalSection(
      id: 'section-6',
      proposalId: 'proposal-1',
      order: 0,
      type: ProposalSectionType.executiveSummary,
      title: 'Executive Summary',
      content: 'Generated content.',
      status: ProposalSectionStatus.aiDrafted,
      aiGeneratedAt: generatedAt,
      aiConfidence: 82,
      aiSourceBusinessUnitIds: const ['unit-1'],
      aiSourceProductIds: const ['product-1'],
      aiSourceServiceIds: const ['service-1'],
      aiSourceCapabilityIds: const ['cap-1'],
      aiSourceTechnologyIds: const ['tech-1'],
      aiSourceIndustryIds: const ['industry-1'],
      aiSourceExperienceIds: const ['experience-1'],
      aiSourceKnowledgeArticleIds: const ['article-1'],
      previousContent: 'Old content.',
      previousStatus: ProposalSectionStatus.edited,
      createdAt: now,
      updatedAt: now,
    );

    final restored = ProposalSection.fromMap(section.id, section.toMap());

    expect(restored.status, ProposalSectionStatus.aiDrafted);
    expect(restored.aiGeneratedAt?.toUtc(), generatedAt.toUtc());
    expect(restored.aiConfidence, 82);
    expect(restored.aiSourceBusinessUnitIds, ['unit-1']);
    expect(restored.aiSourceProductIds, ['product-1']);
    expect(restored.aiSourceServiceIds, ['service-1']);
    expect(restored.aiSourceCapabilityIds, ['cap-1']);
    expect(restored.aiSourceTechnologyIds, ['tech-1']);
    expect(restored.aiSourceIndustryIds, ['industry-1']);
    expect(restored.aiSourceExperienceIds, ['experience-1']);
    expect(restored.aiSourceKnowledgeArticleIds, ['article-1']);
    expect(restored.previousContent, 'Old content.');
    expect(restored.previousStatus, ProposalSectionStatus.edited);
  });

  test(
    'ProposalSection defaults AI generation fields to null/empty when missing',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = ProposalSection.fromMap('section-7', {
        'proposalId': 'proposal-1',
        'type': 'custom',
        'title': 'Custom Section',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.aiGeneratedAt, isNull);
      expect(restored.aiConfidence, isNull);
      expect(restored.aiSourceBusinessUnitIds, isEmpty);
      expect(restored.aiSourceProductIds, isEmpty);
      expect(restored.aiSourceServiceIds, isEmpty);
      expect(restored.aiSourceCapabilityIds, isEmpty);
      expect(restored.aiSourceTechnologyIds, isEmpty);
      expect(restored.aiSourceIndustryIds, isEmpty);
      expect(restored.aiSourceExperienceIds, isEmpty);
      expect(restored.aiSourceKnowledgeArticleIds, isEmpty);
      expect(restored.previousContent, isNull);
      expect(restored.previousStatus, isNull);
    },
  );
}
