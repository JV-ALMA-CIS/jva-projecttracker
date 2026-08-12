import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';
import 'package:jva_projecttracker/services/tender_discovery_metrics.dart';

TenderSource _source({
  required String id,
  TenderSourceStatus status = TenderSourceStatus.active,
  bool enabled = true,
  int healthScore = 100,
  int wins = 0,
  int losses = 0,
  TenderDiscoveryMethod discoveryMethod = TenderDiscoveryMethod.rss,
  DateTime? lastSyncAt,
  int syncFrequencyMinutes = 1440,
}) {
  final now = DateTime(2026, 1, 1);
  return TenderSource(
    id: id,
    name: 'Source $id',
    organization: 'Org $id',
    category: TenderSourceCategory.governmentAgency,
    discoveryMethod: discoveryMethod,
    status: status,
    enabled: enabled,
    healthScore: healthScore,
    wins: wins,
    losses: losses,
    lastSyncAt: lastSyncAt,
    syncFrequencyMinutes: syncFrequencyMinutes,
    createdAt: now,
    updatedAt: now,
  );
}

Opportunity _opportunity({
  required String id,
  required DateTime discoveredAt,
  ClassificationStatus classificationStatus =
      ClassificationStatus.notClassified,
}) {
  return Opportunity(
    id: id,
    title: 'Opportunity $id',
    description: '',
    sourceUrl: 'https://example.com/$id',
    discoveredAt: discoveredAt,
    updatedAt: discoveredAt,
    classificationStatus: classificationStatus,
  );
}

void main() {
  final now = DateTime(2026, 6, 15, 12);

  group('computeTenderDiscoveryMetrics — source counts', () {
    test(
      'counts active/offline/error sources independently of enabled flag',
      () {
        final metrics = computeTenderDiscoveryMetrics(
          sources: [
            _source(id: '1', status: TenderSourceStatus.active),
            _source(id: '2', status: TenderSourceStatus.offline),
            _source(id: '3', status: TenderSourceStatus.error),
            _source(id: '4', status: TenderSourceStatus.active, enabled: false),
          ],
          syncRuns: const [],
          opportunities: const [],
          activeRecommendations: const [],
          duplicates: const {},
          now: now,
        );

        expect(metrics.totalSources, 4);
        // Source 4 is status=active but enabled=false, so it should not
        // count as an active source — enabled is the admin kill switch.
        expect(metrics.activeSources, 1);
        expect(metrics.offlineSources, 1);
        expect(metrics.sourcesWithErrors, 1);
      },
    );
  });

  group('computeTenderDiscoveryMetrics — opportunities', () {
    test(
      'imported-today counts only opportunities discovered since midnight',
      () {
        final metrics = computeTenderDiscoveryMetrics(
          sources: const [],
          syncRuns: const [],
          opportunities: [
            _opportunity(id: 'a', discoveredAt: DateTime(2026, 6, 15, 1)),
            _opportunity(id: 'b', discoveredAt: DateTime(2026, 6, 14, 23, 59)),
          ],
          activeRecommendations: const [],
          duplicates: const {},
          now: now,
        );

        expect(metrics.opportunitiesImportedToday, 1);
      },
    );

    test('awaiting-review counts only notClassified opportunities', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: const [],
        syncRuns: const [],
        opportunities: [
          _opportunity(
            id: 'a',
            discoveredAt: now,
            classificationStatus: ClassificationStatus.notClassified,
          ),
          _opportunity(
            id: 'b',
            discoveredAt: now,
            classificationStatus: ClassificationStatus.processing,
          ),
        ],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.opportunitiesAwaitingReview, 1);
    });
  });

  group('computeTenderDiscoveryMetrics — win rate', () {
    test('is null when no source has any recorded wins/losses', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: [_source(id: '1', wins: 0, losses: 0)],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.averageWinRatePercent, isNull);
    });

    test('averages win rate only across sources with a recorded outcome', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: [
          _source(id: '1', wins: 3, losses: 1), // 75%
          _source(id: '2', wins: 1, losses: 1), // 50%
          _source(id: '3', wins: 0, losses: 0), // excluded — no record
        ],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.averageWinRatePercent, closeTo(62.5, 0.01));
    });
  });

  group('computeTenderDiscoveryMetrics — health score', () {
    test('averages healthScore across enabled sources only', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: [
          _source(id: '1', healthScore: 100),
          _source(id: '2', healthScore: 50),
          _source(id: '3', healthScore: 0, enabled: false),
        ],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.overallHealthScore, 75);
    });

    test('is null when there are no enabled sources', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: [_source(id: '1', enabled: false)],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.overallHealthScore, isNull);
    });
  });

  group('computeTenderDiscoveryMetrics — sync timing', () {
    test('lastSyncAt is the most recent run across all sources', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: const [],
        syncRuns: [
          TenderSyncRun(
            id: 'r1',
            sourceId: '1',
            sourceName: 'A',
            discoveryMethod: TenderDiscoveryMethod.rss,
            status: TenderSyncRunStatus.completed,
            trigger: TenderSyncTrigger.scheduled,
            startedAt: DateTime(2026, 6, 10),
          ),
          TenderSyncRun(
            id: 'r2',
            sourceId: '2',
            sourceName: 'B',
            discoveryMethod: TenderDiscoveryMethod.rss,
            status: TenderSyncRunStatus.completed,
            trigger: TenderSyncTrigger.scheduled,
            startedAt: DateTime(2026, 6, 14),
          ),
        ],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(metrics.lastSyncAt, DateTime(2026, 6, 14));
    });

    test('nextScheduledSyncAt ignores manual and disabled sources', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: [
          _source(
            id: '1',
            discoveryMethod: TenderDiscoveryMethod.manual,
            lastSyncAt: now,
            syncFrequencyMinutes: 60,
          ),
          _source(
            id: '2',
            enabled: false,
            lastSyncAt: now,
            syncFrequencyMinutes: 30,
          ),
          _source(
            id: '3',
            discoveryMethod: TenderDiscoveryMethod.rss,
            lastSyncAt: now,
            syncFrequencyMinutes: 120,
          ),
        ],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: const {},
        now: now,
      );

      expect(
        metrics.nextScheduledSyncAt,
        now.add(const Duration(minutes: 120)),
      );
    });
  });

  group('computeTenderDiscoveryMetrics — recommendations & duplicates', () {
    test(
      'counts distinct recommended opportunity ids, not recommendation count',
      () {
        // NOTE: Recommendation's full constructor wasn't available to me —
        // only its usage (`.status`, `.priority`, `.generatedAt`,
        // `.relatedOpportunityIds`) was visible in providers.dart. If
        // Recommendation has additional required fields, add them here;
        // this test's assertions don't depend on any field beyond these four.
        final metrics = computeTenderDiscoveryMetrics(
          sources: const [],
          syncRuns: const [],
          opportunities: const [],
          activeRecommendations: [
            Recommendation(
              id: 'rec1',
              title: 'Test recommendation 1',
              reasoning: 'Because opp1 and opp2 look strong',
              status: RecommendationStatus.active,
              priority: OpportunityPriority.high,
              generatedAt: now,
              createdAt: now,
              updatedAt: now,
              relatedOpportunityIds: const ['opp1', 'opp2'],
            ),
            Recommendation(
              id: 'rec2',
              title: 'Test recommendation 2',
              reasoning: 'Because opp1 still looks strong',
              status: RecommendationStatus.active,
              priority: OpportunityPriority.medium,
              generatedAt: now,
              createdAt: now,
              updatedAt: now,
              relatedOpportunityIds: const ['opp1'],
            ),
          ],
          duplicates: {'opp3': _opportunity(id: 'orig3', discoveredAt: now)},
          now: now,
        );

        expect(metrics.aiRecommendedOpportunityCount, 2);
      },
    );

    test('duplicate count matches the duplicates map size', () {
      final metrics = computeTenderDiscoveryMetrics(
        sources: const [],
        syncRuns: const [],
        opportunities: const [],
        activeRecommendations: const [],
        duplicates: {
          'opp1': _opportunity(id: 'orig1', discoveredAt: now),
          'opp2': _opportunity(id: 'orig2', discoveredAt: now),
        },
        now: now,
      );

      expect(metrics.duplicateOpportunityCount, 2);
    });
  });
}
