import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

void main() {
  test(
    'Opportunity round-trips from Firestore maps, including classification fields',
    () {
      final discoveredAt = DateTime.utc(2024, 6, 1);
      final updatedAt = DateTime.utc(2024, 6, 2);
      final deadline = DateTime.utc(2024, 9, 1);
      final aiReviewedAt = DateTime.utc(2024, 6, 3);
      final submittedDate = DateTime.utc(2024, 7, 1);
      final decisionDate = DateTime.utc(2024, 8, 15);
      final lastStageUpdated = DateTime.utc(2024, 8, 16);
      final strategicReviewedAt = DateTime.utc(2024, 8, 20);

      final opportunity = Opportunity(
        id: 'opportunity-1',
        title: 'Rural water tender',
        description: 'Design and build rural water network',
        sourceUrl: 'https://example.com/tender/1',
        client: 'Ministry of Water',
        deadline: deadline,
        status: OpportunityStatus.reviewing,
        fitScorePercent: 82,
        fitReasoning: 'Strong match with past water projects',
        tags: const ['water', 'infrastructure'],
        discoveredAt: discoveredAt,
        updatedAt: updatedAt,
        classificationStatus: ClassificationStatus.classified,
        classificationSummary: 'Matches water infrastructure profile',
        industryIds: const ['industry-1'],
        technologyIds: const ['tech-1'],
        businessUnitIds: const ['unit-1'],
        productIds: const ['product-1'],
        serviceIds: const ['service-1'],
        capabilityIds: const ['cap-1'],
        experienceIds: const ['experience-1'],
        knowledgeArticleIds: const ['article-1'],
        opportunityType: 'Tender',
        estimatedBudget: 2500000,
        estimatedDuration: '18 months',
        estimatedComplexity: EstimatedComplexity.high,
        confidenceScore: 75,
        riskLevel: RiskLevel.medium,
        priority: OpportunityPriority.high,
        aiReviewedAt: aiReviewedAt,
        pipelineStage: OpportunityPipelineStage.negotiation,
        assignedTo: 'jane@example.com',
        reviewNotes: 'Looks strong, needs legal review',
        qualificationNotes: 'Budget confirmed with client',
        submittedDate: submittedDate,
        decisionDate: decisionDate,
        closedReason: null,
        lastStageUpdated: lastStageUpdated,
        executiveRecommendation: StrategicReviewRecommendation.pursue,
        executiveSummary: 'Strong strategic fit, recommend pursuing.',
        strategicStrengths: const ['Deep water infrastructure experience'],
        strategicWeaknesses: const ['No local office in the region'],
        strategicRisks: const ['Tight delivery timeline'],
        mitigationStrategies: const ['Partner with a local subcontractor'],
        competitiveAdvantages: const [
          'Proven track record with similar tenders',
        ],
        missingRequirements: const ['ISO 9001 certification'],
        strategicReviewBusinessUnitIds: const ['unit-1'],
        strategicReviewProductIds: const ['product-1'],
        strategicReviewServiceIds: const ['service-1'],
        strategicReviewCapabilityIds: const ['cap-1'],
        strategicReviewTechnologyIds: const ['tech-1'],
        strategicReviewExperienceIds: const ['experience-1'],
        strategicReviewKnowledgeArticleIds: const ['article-1'],
        proposalPositioningStrategy:
            'Lead with the water infrastructure case study.',
        nextRecommendedActions: const [
          'Schedule a scoping call with the client',
        ],
        strategicReviewedAt: strategicReviewedAt,
      );

      final map = opportunity.toMap();
      final restored = Opportunity.fromMap(opportunity.id, map);

      expect(restored.title, opportunity.title);
      expect(restored.status, OpportunityStatus.reviewing);
      expect(restored.fitScorePercent, opportunity.fitScorePercent);
      expect(restored.deadline?.toUtc(), deadline.toUtc());
      expect(restored.classificationStatus, ClassificationStatus.classified);
      expect(restored.classificationSummary, opportunity.classificationSummary);
      expect(restored.industryIds, opportunity.industryIds);
      expect(restored.technologyIds, opportunity.technologyIds);
      expect(restored.businessUnitIds, opportunity.businessUnitIds);
      expect(restored.productIds, opportunity.productIds);
      expect(restored.serviceIds, opportunity.serviceIds);
      expect(restored.capabilityIds, opportunity.capabilityIds);
      expect(restored.experienceIds, opportunity.experienceIds);
      expect(restored.knowledgeArticleIds, opportunity.knowledgeArticleIds);
      expect(restored.opportunityType, opportunity.opportunityType);
      expect(restored.estimatedBudget, opportunity.estimatedBudget);
      expect(restored.estimatedDuration, opportunity.estimatedDuration);
      expect(restored.estimatedComplexity, EstimatedComplexity.high);
      expect(restored.confidenceScore, opportunity.confidenceScore);
      expect(restored.riskLevel, RiskLevel.medium);
      expect(restored.priority, OpportunityPriority.high);
      expect(restored.aiReviewedAt?.toUtc(), aiReviewedAt.toUtc());
      expect(restored.discoveredAt.toUtc(), discoveredAt.toUtc());
      expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
      expect(restored.pipelineStage, OpportunityPipelineStage.negotiation);
      expect(restored.assignedTo, opportunity.assignedTo);
      expect(restored.reviewNotes, opportunity.reviewNotes);
      expect(restored.qualificationNotes, opportunity.qualificationNotes);
      expect(restored.submittedDate?.toUtc(), submittedDate.toUtc());
      expect(restored.decisionDate?.toUtc(), decisionDate.toUtc());
      expect(restored.closedReason, isNull);
      expect(restored.lastStageUpdated?.toUtc(), lastStageUpdated.toUtc());
      expect(
        restored.executiveRecommendation,
        StrategicReviewRecommendation.pursue,
      );
      expect(restored.executiveSummary, opportunity.executiveSummary);
      expect(restored.strategicStrengths, opportunity.strategicStrengths);
      expect(restored.strategicWeaknesses, opportunity.strategicWeaknesses);
      expect(restored.strategicRisks, opportunity.strategicRisks);
      expect(restored.mitigationStrategies, opportunity.mitigationStrategies);
      expect(restored.competitiveAdvantages, opportunity.competitiveAdvantages);
      expect(restored.missingRequirements, opportunity.missingRequirements);
      expect(
        restored.strategicReviewBusinessUnitIds,
        opportunity.strategicReviewBusinessUnitIds,
      );
      expect(
        restored.strategicReviewProductIds,
        opportunity.strategicReviewProductIds,
      );
      expect(
        restored.strategicReviewServiceIds,
        opportunity.strategicReviewServiceIds,
      );
      expect(
        restored.strategicReviewCapabilityIds,
        opportunity.strategicReviewCapabilityIds,
      );
      expect(
        restored.strategicReviewTechnologyIds,
        opportunity.strategicReviewTechnologyIds,
      );
      expect(
        restored.strategicReviewExperienceIds,
        opportunity.strategicReviewExperienceIds,
      );
      expect(
        restored.strategicReviewKnowledgeArticleIds,
        opportunity.strategicReviewKnowledgeArticleIds,
      );
      expect(
        restored.proposalPositioningStrategy,
        opportunity.proposalPositioningStrategy,
      );
      expect(
        restored.nextRecommendedActions,
        opportunity.nextRecommendedActions,
      );
      expect(
        restored.strategicReviewedAt?.toUtc(),
        strategicReviewedAt.toUtc(),
      );
    },
  );

  test(
    'Opportunity defaults classification fields when reading a pre-Milestone-3.1 document',
    () {
      // Mirrors exactly what functions/index.js writes today — no
      // classification fields at all. Confirms existing Cloud-Function-
      // written documents keep working without a data migration.
      final now = DateTime.utc(2024, 6, 1);
      final restored = Opportunity.fromMap('opportunity-2', {
        'title': 'Legacy opportunity',
        'description': 'Discovered before classification existed',
        'sourceUrl': 'https://example.com/tender/2',
        'status': 'discovered',
        'fitScorePercent': 60,
        'discoveredAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.classificationStatus, ClassificationStatus.notClassified);
      expect(restored.classificationSummary, isNull);
      expect(restored.industryIds, isEmpty);
      expect(restored.technologyIds, isEmpty);
      expect(restored.businessUnitIds, isEmpty);
      expect(restored.productIds, isEmpty);
      expect(restored.serviceIds, isEmpty);
      expect(restored.capabilityIds, isEmpty);
      expect(restored.experienceIds, isEmpty);
      expect(restored.knowledgeArticleIds, isEmpty);
      expect(restored.opportunityType, isNull);
      expect(restored.estimatedBudget, isNull);
      expect(restored.estimatedDuration, isNull);
      expect(restored.estimatedComplexity, isNull);
      expect(restored.confidenceScore, isNull);
      expect(restored.riskLevel, isNull);
      expect(restored.priority, isNull);
      expect(restored.aiReviewedAt, isNull);
      expect(restored.pipelineStage, OpportunityPipelineStage.discovered);
      expect(restored.assignedTo, isNull);
      expect(restored.reviewNotes, isNull);
      expect(restored.qualificationNotes, isNull);
      expect(restored.submittedDate, isNull);
      expect(restored.decisionDate, isNull);
      expect(restored.closedReason, isNull);
      expect(restored.lastStageUpdated, isNull);
      expect(restored.executiveRecommendation, isNull);
      expect(restored.executiveSummary, isNull);
      expect(restored.strategicStrengths, isEmpty);
      expect(restored.strategicWeaknesses, isEmpty);
      expect(restored.strategicRisks, isEmpty);
      expect(restored.mitigationStrategies, isEmpty);
      expect(restored.competitiveAdvantages, isEmpty);
      expect(restored.missingRequirements, isEmpty);
      expect(restored.strategicReviewBusinessUnitIds, isEmpty);
      expect(restored.strategicReviewProductIds, isEmpty);
      expect(restored.strategicReviewServiceIds, isEmpty);
      expect(restored.strategicReviewCapabilityIds, isEmpty);
      expect(restored.strategicReviewTechnologyIds, isEmpty);
      expect(restored.strategicReviewExperienceIds, isEmpty);
      expect(restored.strategicReviewKnowledgeArticleIds, isEmpty);
      expect(restored.proposalPositioningStrategy, isNull);
      expect(restored.nextRecommendedActions, isEmpty);
      expect(restored.strategicReviewedAt, isNull);
    },
  );

  test(
    'Opportunity round-trips discoverySourceId/discoverySourceType and the archived status',
    () {
      final now = DateTime.utc(2024, 6, 1);
      final opportunity = Opportunity(
        id: 'opportunity-3',
        title: 'Government road tender',
        description: 'Rehabilitate a rural road network',
        sourceUrl: 'https://example.com/tender/3',
        status: OpportunityStatus.archived,
        discoveredAt: now,
        updatedAt: now,
        discoverySourceId: 'source-1',
        discoverySourceType: DiscoverySourceType.governmentProcurement,
      );

      final restored = Opportunity.fromMap(opportunity.id, opportunity.toMap());

      expect(restored.status, OpportunityStatus.archived);
      expect(restored.discoverySourceId, 'source-1');
      expect(
        restored.discoverySourceType,
        DiscoverySourceType.governmentProcurement,
      );
    },
  );

  test(
    'Opportunity defaults discoverySourceId/discoverySourceType to null for a document written before the Discovery Engine existed',
    () {
      final now = DateTime.utc(2024, 6, 1);
      final restored = Opportunity.fromMap('opportunity-4', {
        'title': 'Legacy opportunity',
        'description': 'Discovered before the Discovery Engine existed',
        'sourceUrl': 'https://example.com/tender/4',
        'status': 'discovered',
        'fitScorePercent': 55,
        'discoveredAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.discoverySourceId, isNull);
      expect(restored.discoverySourceType, isNull);
    },
  );

  test('Opportunity round-trips sourceUrlVerified and sourceUrlVerifiedAt', () {
    final now = DateTime.utc(2024, 6, 1);
    final verifiedAt = DateTime.utc(2024, 6, 2);
    final opportunity = Opportunity(
      id: 'opportunity-5',
      title: 'Verified tender',
      description: 'A tender whose sourceUrl was confirmed reachable',
      sourceUrl: 'https://example.com/tender/5',
      sourceUrlVerified: true,
      sourceUrlVerifiedAt: verifiedAt,
      discoveredAt: now,
      updatedAt: now,
    );

    final restored = Opportunity.fromMap(opportunity.id, opportunity.toMap());

    expect(restored.sourceUrlVerified, isTrue);
    expect(restored.sourceUrlVerifiedAt?.toUtc(), verifiedAt.toUtc());
  });

  test('Opportunity defaults sourceUrlVerified to false — a legacy document '
      'predating this field was never actually checked, so it must not be '
      'silently treated as verified', () {
    final now = DateTime.utc(2024, 6, 1);
    final restored = Opportunity.fromMap('opportunity-6', {
      'title': 'Legacy opportunity',
      'description': 'Discovered before sourceUrlVerified existed',
      'sourceUrl': 'https://example.com/tender/6',
      'status': 'discovered',
      'fitScorePercent': 50,
      'discoveredAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.sourceUrlVerified, isFalse);
    expect(restored.sourceUrlVerifiedAt, isNull);
  });

  test(
    'a freshly-constructed Opportunity with no explicit sourceUrlVerified defaults to false',
    () {
      final now = DateTime.utc(2024, 6, 1);
      final opportunity = Opportunity(
        id: 'opportunity-7',
        title: 'New opportunity',
        description: '',
        sourceUrl: 'https://example.com/tender/7',
        discoveredAt: now,
        updatedAt: now,
      );

      expect(opportunity.sourceUrlVerified, isFalse);
      expect(opportunity.sourceUrlVerifiedAt, isNull);
    },
  );
}
