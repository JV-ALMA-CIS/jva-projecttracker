import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';

void main() {
  test('Recommendation round-trips from Firestore maps', () {
    final generatedAt = DateTime.utc(2024, 8, 1);
    final createdAt = DateTime.utc(2024, 8, 1);
    final updatedAt = DateTime.utc(2024, 8, 2);

    final recommendation = Recommendation(
      id: 'recommendation-1',
      category: RecommendationCategory.priorityOpportunity,
      priority: OpportunityPriority.high,
      title: 'Fast-track the Rural Water Tender',
      reasoning: 'Strong strategic fit and an approaching deadline.',
      confidenceScore: 82,
      status: RecommendationStatus.active,
      relatedOpportunityIds: const ['opportunity-1'],
      relatedBusinessUnitIds: const ['unit-1'],
      relatedProductIds: const ['product-1'],
      relatedServiceIds: const ['service-1'],
      relatedCapabilityIds: const ['cap-1'],
      relatedTechnologyIds: const ['tech-1'],
      relatedIndustryIds: const ['industry-1'],
      relatedExperienceIds: const ['experience-1'],
      relatedKnowledgeArticleIds: const ['article-1'],
      generatedAt: generatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = recommendation.toMap();
    final restored = Recommendation.fromMap(recommendation.id, map);

    expect(restored.category, RecommendationCategory.priorityOpportunity);
    expect(restored.priority, OpportunityPriority.high);
    expect(restored.title, recommendation.title);
    expect(restored.reasoning, recommendation.reasoning);
    expect(restored.confidenceScore, 82);
    expect(restored.status, RecommendationStatus.active);
    expect(
      restored.relatedOpportunityIds,
      recommendation.relatedOpportunityIds,
    );
    expect(
      restored.relatedBusinessUnitIds,
      recommendation.relatedBusinessUnitIds,
    );
    expect(restored.relatedProductIds, recommendation.relatedProductIds);
    expect(restored.relatedServiceIds, recommendation.relatedServiceIds);
    expect(restored.relatedCapabilityIds, recommendation.relatedCapabilityIds);
    expect(restored.relatedTechnologyIds, recommendation.relatedTechnologyIds);
    expect(restored.relatedIndustryIds, recommendation.relatedIndustryIds);
    expect(restored.relatedExperienceIds, recommendation.relatedExperienceIds);
    expect(
      restored.relatedKnowledgeArticleIds,
      recommendation.relatedKnowledgeArticleIds,
    );
    expect(restored.generatedAt.toUtc(), generatedAt.toUtc());
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('Recommendation defaults missing fields on a partial document', () {
    final now = DateTime.utc(2024, 8, 1);
    final restored = Recommendation.fromMap('recommendation-2', {
      'title': 'Investigate a capability gap',
      'reasoning': 'Three recent opportunities all needed this.',
      'generatedAt': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.category, RecommendationCategory.general);
    expect(restored.priority, OpportunityPriority.medium);
    expect(restored.confidenceScore, isNull);
    expect(restored.status, RecommendationStatus.active);
    expect(restored.relatedOpportunityIds, isEmpty);
    expect(restored.relatedBusinessUnitIds, isEmpty);
    expect(restored.relatedProductIds, isEmpty);
    expect(restored.relatedServiceIds, isEmpty);
    expect(restored.relatedCapabilityIds, isEmpty);
    expect(restored.relatedTechnologyIds, isEmpty);
    expect(restored.relatedIndustryIds, isEmpty);
    expect(restored.relatedExperienceIds, isEmpty);
    expect(restored.relatedKnowledgeArticleIds, isEmpty);
  });
}
