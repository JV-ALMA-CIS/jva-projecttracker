import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';
import 'package:jva_projecttracker/services/tender_analytics.dart';
import 'package:jva_projecttracker/services/tender_connection_test_service.dart';
import 'package:jva_projecttracker/services/tender_discovery_metrics.dart';
import 'package:jva_projecttracker/services/tender_source_seed_service.dart';
import 'package:jva_projecttracker/services/tender_source_service.dart';
import 'package:jva_projecttracker/services/tender_sync_run_service.dart';
import 'package:jva_projecttracker/services/tender_sync_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../recommendations/recommendation_providers.dart';

// --- Add near the existing discoverySourceServiceProvider /
//     discoveryEngineServiceProvider declarations (around line 166-171).
//     Kept as a fully separate provider family from the discoverySource*
//     providers above/below it — DiscoverySource stays live and untouched
//     until it's formally retired; nothing here reads or writes it. ---
final tenderSourceServiceProvider = Provider((ref) => TenderSourceService());
final tenderSyncServiceProvider = Provider((ref) => TenderSyncService());
final tenderSyncRunServiceProvider = Provider((ref) => TenderSyncRunService());
// --- Add alongside tenderSourceServiceProvider / tenderSyncServiceProvider ---
final tenderConnectionTestServiceProvider = Provider(
  (ref) => TenderConnectionTestService(),
);

/// All configured Tender Sources, live, name-sorted — backs the (upcoming)
/// Tender Sources admin workspace, Milestone 3.8b.
final tenderSourcesStreamProvider = StreamProvider<List<TenderSource>>((ref) {
  return ref.watch(tenderSourceServiceProvider).watchAll();
});

/// A single Tender Source by id, live — backs the (upcoming) Source
/// Workspace, Milestone 3.8c.
final tenderSourceByIdProvider = StreamProvider.autoDispose
    .family<TenderSource?, String>((ref, id) {
      return ref.watch(tenderSourceServiceProvider).watchById(id);
    });

/// Every Tender sync run across every source, live, most recent first.
final tenderSyncRunsStreamProvider = StreamProvider<List<TenderSyncRun>>((ref) {
  return ref.watch(tenderSyncRunServiceProvider).watchAll();
});

/// Sync history scoped to a single source, live, most recent first.
final tenderSyncRunsBySourceProvider =
    StreamProvider.family<List<TenderSyncRun>, String>((ref, sourceId) {
      return ref.watch(tenderSyncRunServiceProvider).watchBySource(sourceId);
    });

// --- Add alongside the other Tender Source service providers ---
final tenderSourceSeedServiceProvider = Provider(
  (ref) => TenderSourceSeedService(),
);

// --- Add anywhere after tenderSourcesStreamProvider, tenderSyncRunsStreamProvider,
//     activeRecommendationsProvider, and opportunityDuplicatesProvider are all
//     defined (order doesn't matter to Riverpod, but keeping it near the other
//     Tender Source providers matches the file's existing grouping-by-feature). ---

/// The Discovery Dashboard's KPIs (Milestone 3.8b). Same "derive from
/// already-live providers, no new Firestore reads" idiom as
/// [executiveMetricsProvider] — see computeTenderDiscoveryMetrics for the
/// pure calculation, kept separate from this provider so it's unit-testable
/// without Riverpod.
final tenderDiscoveryMetricsProvider = Provider<TenderDiscoveryMetrics>((ref) {
  return computeTenderDiscoveryMetrics(
    sources: ref.watch(tenderSourcesStreamProvider).value ?? const [],
    syncRuns: ref.watch(tenderSyncRunsStreamProvider).value ?? const [],
    opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
    activeRecommendations: ref.watch(activeRecommendationsProvider),
    duplicates: ref.watch(opportunityDuplicatesProvider),
    now: DateTime.now(),
  );
});

/// The 8 most recent Tender sync runs, for the Dashboard's compact activity
/// feed — same "derive, then take(n)" shape as [topRecommendationsProvider]/
/// [topProposalsProvider].
final recentTenderSyncRunsProvider = Provider<List<TenderSyncRun>>((ref) {
  return ref.watch(tenderSyncRunsStreamProvider).value?.take(8).toList() ??
      const [];
});

// --- Milestone 3.8d — Tender Analytics ---

/// Every opportunity that came from a TenderSource (i.e. has
/// `tenderSourceId` set) — derived in-memory from the same
/// [opportunitiesStreamProvider] every other Opportunities view already
/// uses, not a separate Firestore query. This is the base dataset every
/// other Tender Analytics provider below filters/groups further.
final tenderSourcedOpportunitiesProvider = Provider<List<Opportunity>>((ref) {
  final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
  return all.where((o) => o.tenderSourceId != null).toList();
});

/// Opportunities scoped to a single source — backs the Source Workspace's
/// Import History.
final tenderSourceOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, sourceId) {
      return ref
          .watch(tenderSourcedOpportunitiesProvider)
          .where((o) => o.tenderSourceId == sourceId)
          .toList();
    });

final tenderAnalyticsSummaryProvider = Provider<TenderAnalyticsSummary>((ref) {
  return computeTenderAnalyticsSummary(
    ref.watch(tenderSourcedOpportunitiesProvider),
  );
});

final tenderMonthlyOpportunityTrendProvider =
    Provider<List<MonthlyOpportunityCount>>((ref) {
      return computeMonthlyOpportunityTrend(
        ref.watch(tenderSourcedOpportunitiesProvider),
        now: DateTime.now(),
      );
    });

/// Per-source monthly trend, for the Source Workspace's trend section.
final tenderSourceMonthlyTrendProvider =
    Provider.family<List<MonthlyOpportunityCount>, String>((ref, sourceId) {
      return computeMonthlyOpportunityTrend(
        ref.watch(tenderSourceOpportunitiesProvider(sourceId)),
        now: DateTime.now(),
      );
    });

final tenderBusinessUnitPerformanceProvider =
    Provider<List<BusinessUnitPerformance>>((ref) {
      return computeBusinessUnitPerformance(
        ref.watch(tenderSourcedOpportunitiesProvider),
      );
    });

final tenderSectorPerformanceProvider = Provider<List<SectorPerformance>>((
  ref,
) {
  return computeSectorPerformance(
    ref.watch(tenderSourcesStreamProvider).value ?? const [],
    ref.watch(tenderSourcedOpportunitiesProvider),
  );
});

final tenderSourcePerformanceRankingProvider =
    Provider<List<TenderSourcePerformance>>((ref) {
      return computeSourcePerformanceRanking(
        ref.watch(tenderSourcesStreamProvider).value ?? const [],
        ref.watch(tenderSourcedOpportunitiesProvider),
      );
    });
