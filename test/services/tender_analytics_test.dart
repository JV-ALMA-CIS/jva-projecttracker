import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/services/tender_analytics.dart';

TenderSource _source({
  required String id,
  List<String> tags = const [],
  int wins = 0,
  int losses = 0,
  double? historicalWinRatePercent,
}) {
  final now = DateTime(2026, 1, 1);
  return TenderSource(
    id: id,
    name: 'Source $id',
    organization: 'Org $id',
    category: TenderSourceCategory.governmentAgency,
    discoveryMethod: TenderDiscoveryMethod.rss,
    tags: tags,
    wins: wins,
    losses: losses,
    historicalWinRatePercent: historicalWinRatePercent,
    createdAt: now,
    updatedAt: now,
  );
}

Opportunity _opportunity({
  required String id,
  required DateTime discoveredAt,
  OpportunityStatus status = OpportunityStatus.discovered,
  String? tenderSourceId,
  List<String> businessUnitIds = const [],
  double? estimatedBudget,
  int? confidenceScore,
}) {
  return Opportunity(
    id: id,
    title: 'Opportunity $id',
    description: '',
    sourceUrl: 'https://example.com/$id',
    discoveredAt: discoveredAt,
    updatedAt: discoveredAt,
    status: status,
    tenderSourceId: tenderSourceId,
    businessUnitIds: businessUnitIds,
    estimatedBudget: estimatedBudget,
    confidenceScore: confidenceScore,
  );
}

void main() {
  final now = DateTime(2026, 6, 15);

  group('computeMonthlyOpportunityTrend', () {
    test('includes zero-count months rather than omitting gaps', () {
      final trend = computeMonthlyOpportunityTrend(
        [_opportunity(id: 'a', discoveredAt: DateTime(2026, 6, 1))],
        now: now,
        monthCount: 3,
      );

      expect(trend, hasLength(3));
      expect(trend.map((m) => m.count), [0, 0, 1]); // Apr, May, Jun
      expect(trend.last.month, DateTime(2026, 6));
    });

    test('groups multiple opportunities in the same month together', () {
      final trend = computeMonthlyOpportunityTrend(
        [
          _opportunity(id: 'a', discoveredAt: DateTime(2026, 6, 1)),
          _opportunity(id: 'b', discoveredAt: DateTime(2026, 6, 28)),
        ],
        now: now,
        monthCount: 1,
      );

      expect(trend.single.count, 2);
    });
  });

  group('computeTenderAnalyticsSummary', () {
    test('pursued counts applied/won/lost but not discovered/reviewing', () {
      final summary = computeTenderAnalyticsSummary([
        _opportunity(
          id: 'a',
          discoveredAt: now,
          status: OpportunityStatus.discovered,
        ),
        _opportunity(
          id: 'b',
          discoveredAt: now,
          status: OpportunityStatus.reviewing,
        ),
        _opportunity(
          id: 'c',
          discoveredAt: now,
          status: OpportunityStatus.applied,
        ),
        _opportunity(id: 'd', discoveredAt: now, status: OpportunityStatus.won),
        _opportunity(
          id: 'e',
          discoveredAt: now,
          status: OpportunityStatus.lost,
        ),
      ]);

      expect(summary.discovered, 5);
      expect(summary.pursued, 3);
      expect(summary.wins, 1);
      expect(summary.losses, 1);
      expect(summary.winRatePercent, 50.0);
    });

    test('contract value only sums won opportunities', () {
      final summary = computeTenderAnalyticsSummary([
        _opportunity(
          id: 'a',
          discoveredAt: now,
          status: OpportunityStatus.won,
          estimatedBudget: 10000,
        ),
        _opportunity(
          id: 'b',
          discoveredAt: now,
          status: OpportunityStatus.lost,
          estimatedBudget: 5000,
        ),
      ]);

      expect(summary.totalContractValueWon, 10000);
    });

    test(
      'averageAiConfidence ignores opportunities with no confidenceScore',
      () {
        final summary = computeTenderAnalyticsSummary([
          _opportunity(id: 'a', discoveredAt: now, confidenceScore: 80),
          _opportunity(id: 'b', discoveredAt: now, confidenceScore: 60),
          _opportunity(id: 'c', discoveredAt: now), // no score
        ]);

        expect(summary.averageAiConfidence, 70.0);
      },
    );

    test('winRatePercent is null when there are no wins or losses', () {
      final summary = computeTenderAnalyticsSummary([
        _opportunity(
          id: 'a',
          discoveredAt: now,
          status: OpportunityStatus.discovered,
        ),
      ]);

      expect(summary.winRatePercent, isNull);
    });
  });

  group('computeBusinessUnitPerformance', () {
    test('an opportunity with multiple business units counts toward each', () {
      final result = computeBusinessUnitPerformance([
        _opportunity(
          id: 'a',
          discoveredAt: now,
          businessUnitIds: ['bu1', 'bu2'],
          status: OpportunityStatus.won,
        ),
      ]);

      expect(result, hasLength(2));
      expect(
        result.every((r) => r.opportunityCount == 1 && r.wins == 1),
        isTrue,
      );
    });

    test('sorted by opportunity count descending', () {
      final result = computeBusinessUnitPerformance([
        _opportunity(id: 'a', discoveredAt: now, businessUnitIds: ['bu1']),
        _opportunity(id: 'b', discoveredAt: now, businessUnitIds: ['bu2']),
        _opportunity(id: 'c', discoveredAt: now, businessUnitIds: ['bu2']),
      ]);

      expect(result.first.businessUnitId, 'bu2');
      expect(result.first.opportunityCount, 2);
    });
  });

  group('computeSourcePerformanceRanking', () {
    test('sources with a recorded win rate rank above those without', () {
      final result = computeSourcePerformanceRanking([
        _source(id: '1', historicalWinRatePercent: null),
        _source(id: '2', historicalWinRatePercent: 40),
      ], const []);

      expect(result.first.source.id, '2');
      expect(result.last.source.id, '1');
    });

    test('ties in win rate break by opportunity count', () {
      final result = computeSourcePerformanceRanking(
        [
          _source(id: '1', historicalWinRatePercent: 50),
          _source(id: '2', historicalWinRatePercent: 50),
        ],
        [
          _opportunity(id: 'a', discoveredAt: now, tenderSourceId: '2'),
          _opportunity(id: 'b', discoveredAt: now, tenderSourceId: '2'),
          _opportunity(id: 'c', discoveredAt: now, tenderSourceId: '1'),
        ],
      );

      expect(result.first.source.id, '2');
      expect(result.first.opportunityCount, 2);
    });
  });

  group('computeSectorPerformance', () {
    test('attributes an opportunity to every tag on its producing source', () {
      final result = computeSectorPerformance(
        [
          _source(id: 's1', tags: const ['agriculture', 'infrastructure']),
        ],
        [
          _opportunity(
            id: 'a',
            discoveredAt: now,
            tenderSourceId: 's1',
            status: OpportunityStatus.won,
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(
        result.every((r) => r.opportunityCount == 1 && r.wins == 1),
        isTrue,
      );
    });

    test('opportunities with no matching source contribute nothing', () {
      final result = computeSectorPerformance(const [], [
        _opportunity(id: 'a', discoveredAt: now, tenderSourceId: 'missing'),
      ]);

      expect(result, isEmpty);
    });
  });
}
