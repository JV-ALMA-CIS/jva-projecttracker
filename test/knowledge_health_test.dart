import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';

class _TestEntity {
  const _TestEntity(this.id, this.updatedAt);
  final String id;
  final DateTime updatedAt;
}

Opportunity _opportunity({
  required String id,
  List<String> businessUnitIds = const [],
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Opportunity(
    id: id,
    title: 'Opportunity $id',
    description: '',
    sourceUrl: 'https://example.com/$id',
    discoveredAt: now,
    updatedAt: now,
    businessUnitIds: businessUnitIds,
  );
}

Recommendation _recommendation({
  required String id,
  List<String> relatedBusinessUnitIds = const [],
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Recommendation(
    id: id,
    title: 'Recommendation $id',
    reasoning: '',
    relatedBusinessUnitIds: relatedBusinessUnitIds,
    generatedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

KnowledgeEntitySummary<_TestEntity> _summarize({
  required List<_TestEntity> entities,
  List<Opportunity> opportunities = const [],
  List<Recommendation> recommendations = const [],
}) {
  return summarizeKnowledgeEntities<_TestEntity>(
    entities: entities,
    idOf: (e) => e.id,
    updatedAtOf: (e) => e.updatedAt,
    opportunities: opportunities,
    recommendations: recommendations,
    opportunityReferencedIds: (o) => o.businessUnitIds.toSet(),
    recommendationReferencedIds: (r) => r.relatedBusinessUnitIds.toSet(),
  );
}

void main() {
  test('returns noData when there are zero entities of this type', () {
    final summary = _summarize(entities: const []);

    expect(summary.count, 0);
    expect(summary.mostRecentlyUpdated, isNull);
    expect(summary.relatedOpportunityCount, 0);
    expect(summary.health, KnowledgeHealth.noData);
  });

  test(
    'returns gap when entities exist but none are referenced by any opportunity or recommendation',
    () {
      final summary = _summarize(
        entities: [_TestEntity('a', DateTime.utc(2024, 1, 1))],
        opportunities: [_opportunity(id: 'opp-1')],
      );

      expect(summary.health, KnowledgeHealth.gap);
      expect(summary.relatedOpportunityCount, 0);
    },
  );

  test('returns attention when coverage is below 50%', () {
    final summary = _summarize(
      entities: [
        _TestEntity('a', DateTime.utc(2024, 1, 1)),
        _TestEntity('b', DateTime.utc(2024, 1, 2)),
        _TestEntity('c', DateTime.utc(2024, 1, 3)),
      ],
      opportunities: [
        _opportunity(id: 'opp-1', businessUnitIds: const ['a']),
      ],
    );

    expect(summary.health, KnowledgeHealth.attention);
    expect(summary.relatedOpportunityCount, 1);
  });

  test('returns covered when coverage is at or above 50%', () {
    final summary = _summarize(
      entities: [
        _TestEntity('a', DateTime.utc(2024, 1, 1)),
        _TestEntity('b', DateTime.utc(2024, 1, 2)),
      ],
      opportunities: [
        _opportunity(id: 'opp-1', businessUnitIds: const ['a']),
        _opportunity(id: 'opp-2', businessUnitIds: const ['b']),
      ],
    );

    expect(summary.health, KnowledgeHealth.covered);
    expect(summary.relatedOpportunityCount, 2);
  });

  test(
    'a recommendation-only reference is enough to count toward coverage',
    () {
      final summary = _summarize(
        entities: [
          _TestEntity('a', DateTime.utc(2024, 1, 1)),
          _TestEntity('b', DateTime.utc(2024, 1, 2)),
        ],
        recommendations: [
          _recommendation(
            id: 'rec-1',
            relatedBusinessUnitIds: const ['a', 'b'],
          ),
        ],
      );

      expect(summary.health, KnowledgeHealth.covered);
      // Recommendations don't count toward relatedOpportunityCount — only
      // opportunities do.
      expect(summary.relatedOpportunityCount, 0);
    },
  );

  test(
    'relatedOpportunityCount only counts opportunities with a non-empty referenced-ids set',
    () {
      final summary = _summarize(
        entities: [_TestEntity('a', DateTime.utc(2024, 1, 1))],
        opportunities: [
          _opportunity(id: 'opp-1', businessUnitIds: const ['a']),
          _opportunity(id: 'opp-2'),
        ],
      );

      expect(summary.relatedOpportunityCount, 1);
    },
  );

  test('mostRecentlyUpdated picks the true maximum by updatedAt', () {
    final latest = _TestEntity('c', DateTime.utc(2024, 6, 1));
    final summary = _summarize(
      entities: [
        _TestEntity('a', DateTime.utc(2024, 1, 1)),
        latest,
        _TestEntity('b', DateTime.utc(2024, 3, 1)),
      ],
    );

    expect(summary.mostRecentlyUpdated, latest);
  });
}
