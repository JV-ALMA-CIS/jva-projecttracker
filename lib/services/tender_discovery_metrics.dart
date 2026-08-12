import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';

/// The Discovery Dashboard's KPIs (Milestone 3.8b). Every field is derived
/// from data already live via other providers — no new Firestore reads —
/// matching [executiveMetricsProvider]'s "derive, don't re-fetch" idiom.
class TenderDiscoveryMetrics {
  const TenderDiscoveryMetrics({
    required this.totalSources,
    required this.activeSources,
    required this.offlineSources,
    required this.sourcesWithErrors,
    required this.opportunitiesImportedToday,
    required this.opportunitiesAwaitingReview,
    required this.duplicateOpportunityCount,
    required this.aiRecommendedOpportunityCount,
    required this.averageWinRatePercent,
    required this.overallHealthScore,
    required this.lastSyncAt,
    required this.nextScheduledSyncAt,
  });

  final int totalSources;
  final int activeSources;
  final int offlineSources;
  final int sourcesWithErrors;

  final int opportunitiesImportedToday;
  final int opportunitiesAwaitingReview;
  final int duplicateOpportunityCount;
  final int aiRecommendedOpportunityCount;

  /// Null when no source has recorded any wins/losses yet.
  final double? averageWinRatePercent;

  /// 0-100 average of every enabled source's `healthScore`. Null when
  /// there are no enabled sources.
  final int? overallHealthScore;

  final DateTime? lastSyncAt;

  /// Best-effort estimate only — the actual next run depends on
  /// `scheduledTenderSourceSync`'s hourly tick, not a precise timer.
  final DateTime? nextScheduledSyncAt;
}

TenderDiscoveryMetrics computeTenderDiscoveryMetrics({
  required List<TenderSource> sources,
  required List<TenderSyncRun> syncRuns,
  required List<Opportunity> opportunities,
  required List<Recommendation> activeRecommendations,
  required Map<String, Opportunity> duplicates,
  required DateTime now,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);

  final activeSources = sources
      .where((s) => s.enabled && s.status == TenderSourceStatus.active)
      .length;
  final offlineSources = sources
      .where((s) => s.status == TenderSourceStatus.offline)
      .length;
  final sourcesWithErrors = sources
      .where((s) => s.status == TenderSourceStatus.error)
      .length;

  final importedToday = opportunities
      .where((o) => !o.discoveredAt.isBefore(startOfToday))
      .length;

  final awaitingReview = opportunities
      .where(
        (o) => o.classificationStatus == ClassificationStatus.notClassified,
      )
      .length;

  final recommendedOpportunityIds = <String>{
    for (final r in activeRecommendations) ...r.relatedOpportunityIds,
  };

  final sourcesWithRecord = sources.where((s) => s.wins + s.losses > 0);
  double? averageWinRate;
  if (sourcesWithRecord.isNotEmpty) {
    final rates = sourcesWithRecord.map(
      (s) => s.wins / (s.wins + s.losses) * 100,
    );
    averageWinRate = rates.reduce((a, b) => a + b) / rates.length;
  }

  final enabledSources = sources.where((s) => s.enabled);
  int? overallHealth;
  if (enabledSources.isNotEmpty) {
    overallHealth =
        (enabledSources.map((s) => s.healthScore).reduce((a, b) => a + b) /
                enabledSources.length)
            .round();
  }

  DateTime? lastSyncAt;
  for (final run in syncRuns) {
    if (lastSyncAt == null || run.startedAt.isAfter(lastSyncAt)) {
      lastSyncAt = run.startedAt;
    }
  }

  DateTime? nextScheduledSyncAt;
  for (final source in sources) {
    if (!source.enabled ||
        source.discoveryMethod == TenderDiscoveryMethod.manual) {
      continue;
    }
    final base = source.lastSyncAt ?? now;
    final candidate = base.add(Duration(minutes: source.syncFrequencyMinutes));
    if (nextScheduledSyncAt == null ||
        candidate.isBefore(nextScheduledSyncAt)) {
      nextScheduledSyncAt = candidate;
    }
  }

  return TenderDiscoveryMetrics(
    totalSources: sources.length,
    activeSources: activeSources,
    offlineSources: offlineSources,
    sourcesWithErrors: sourcesWithErrors,
    opportunitiesImportedToday: importedToday,
    opportunitiesAwaitingReview: awaitingReview,
    duplicateOpportunityCount: duplicates.length,
    aiRecommendedOpportunityCount: recommendedOpportunityIds.length,
    averageWinRatePercent: averageWinRate,
    overallHealthScore: overallHealth,
    lastSyncAt: lastSyncAt,
    nextScheduledSyncAt: nextScheduledSyncAt,
  );
}
