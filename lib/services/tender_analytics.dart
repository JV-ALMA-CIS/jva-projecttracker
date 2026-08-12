import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

/// One calendar month's opportunity count, for the trend chart.
class MonthlyOpportunityCount {
  const MonthlyOpportunityCount({required this.month, required this.count});
  final DateTime month; // always the 1st of the month
  final int count;
}

/// Groups [opportunities] by the calendar month of `discoveredAt`, for the
/// last [monthCount] months ending with the current month (oldest first).
/// Months with zero opportunities are included as 0, not omitted, so the
/// trend chart doesn't silently skip gaps.
List<MonthlyOpportunityCount> computeMonthlyOpportunityTrend(
  List<Opportunity> opportunities, {
  required DateTime now,
  int monthCount = 6,
}) {
  final months = List.generate(monthCount, (i) {
    final target = DateTime(now.year, now.month - (monthCount - 1 - i));
    return DateTime(target.year, target.month);
  });

  final counts = {for (final m in months) m: 0};
  for (final o in opportunities) {
    final key = DateTime(o.discoveredAt.year, o.discoveredAt.month);
    if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
  }

  return [
    for (final m in months)
      MonthlyOpportunityCount(month: m, count: counts[m]!),
  ];
}

/// Overall Tender Analytics totals, defined for the whole engine (across
/// every TenderSource) rather than per-source — see [TenderSourcePerformance]
/// for the per-source ranking.
///
/// ASSUMPTION: "pursued" = status has moved past `reviewing` — i.e.
/// `applied`, `won`, or `lost` — meaning a proposal was actually put
/// forward, not just reviewed. Not explicitly defined in the brief; stated
/// here so it's easy to correct if a different definition was intended.
class TenderAnalyticsSummary {
  const TenderAnalyticsSummary({
    required this.discovered,
    required this.pursued,
    required this.wins,
    required this.losses,
    required this.winRatePercent,
    required this.totalContractValueWon,
    required this.averageAiConfidence,
  });

  final int discovered;
  final int pursued;
  final int wins;
  final int losses;
  final double? winRatePercent;
  final double totalContractValueWon;
  final double? averageAiConfidence;
}

TenderAnalyticsSummary computeTenderAnalyticsSummary(
  List<Opportunity> tenderOpportunities,
) {
  final discovered = tenderOpportunities.length;
  final pursued = tenderOpportunities
      .where(
        (o) =>
            o.status == OpportunityStatus.applied ||
            o.status == OpportunityStatus.won ||
            o.status == OpportunityStatus.lost,
      )
      .length;
  final wins = tenderOpportunities
      .where((o) => o.status == OpportunityStatus.won)
      .length;
  final losses = tenderOpportunities
      .where((o) => o.status == OpportunityStatus.lost)
      .length;
  final winRate = (wins + losses) > 0 ? wins / (wins + losses) * 100 : null;

  final contractValue = tenderOpportunities
      .where((o) => o.status == OpportunityStatus.won)
      .fold<double>(0, (sum, o) => sum + (o.estimatedBudget ?? 0));

  final confidenceScores = tenderOpportunities
      .map((o) => o.confidenceScore)
      .whereType<int>()
      .toList();
  final avgConfidence = confidenceScores.isEmpty
      ? null
      : confidenceScores.reduce((a, b) => a + b) / confidenceScores.length;

  return TenderAnalyticsSummary(
    discovered: discovered,
    pursued: pursued,
    wins: wins,
    losses: losses,
    winRatePercent: winRate,
    totalContractValueWon: contractValue,
    averageAiConfidence: avgConfidence,
  );
}

/// A single business unit's performance across every Tender-sourced
/// opportunity referencing it.
class BusinessUnitPerformance {
  const BusinessUnitPerformance({
    required this.businessUnitId,
    required this.opportunityCount,
    required this.wins,
  });

  final String businessUnitId;
  final int opportunityCount;
  final int wins;
}

/// Ranked by opportunity count, descending. An opportunity referencing
/// multiple business units counts toward each — matches the existing
/// many-to-many `businessUnitIds` relationship rather than picking one.
List<BusinessUnitPerformance> computeBusinessUnitPerformance(
  List<Opportunity> tenderOpportunities,
) {
  final counts = <String, int>{};
  final wins = <String, int>{};

  for (final o in tenderOpportunities) {
    for (final id in o.businessUnitIds) {
      counts[id] = (counts[id] ?? 0) + 1;
      if (o.status == OpportunityStatus.won) {
        wins[id] = (wins[id] ?? 0) + 1;
      }
    }
  }

  final result = [
    for (final id in counts.keys)
      BusinessUnitPerformance(
        businessUnitId: id,
        opportunityCount: counts[id]!,
        wins: wins[id] ?? 0,
      ),
  ];
  result.sort((a, b) => b.opportunityCount.compareTo(a.opportunityCount));
  return result;
}

/// A single sector's (TenderSource tag's) performance. "Sector" here means
/// the TenderSource's own `tags` field — the brief didn't define what a
/// "sector" is independently of a source, so this treats each source's
/// tags as the sectors it covers, and attributes every opportunity it
/// produced to all of them.
class SectorPerformance {
  const SectorPerformance({
    required this.sector,
    required this.opportunityCount,
    required this.wins,
  });

  final String sector;
  final int opportunityCount;
  final int wins;
}

/// Ranked by opportunity count, descending.
List<SectorPerformance> computeSectorPerformance(
  List<TenderSource> sources,
  List<Opportunity> tenderOpportunities,
) {
  final tagsBySourceId = {for (final s in sources) s.id: s.tags};
  final counts = <String, int>{};
  final wins = <String, int>{};

  for (final o in tenderOpportunities) {
    final tags = tagsBySourceId[o.tenderSourceId] ?? const [];
    for (final tag in tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
      if (o.status == OpportunityStatus.won) {
        wins[tag] = (wins[tag] ?? 0) + 1;
      }
    }
  }

  final result = [
    for (final tag in counts.keys)
      SectorPerformance(
        sector: tag,
        opportunityCount: counts[tag]!,
        wins: wins[tag] ?? 0,
      ),
  ];
  result.sort((a, b) => b.opportunityCount.compareTo(a.opportunityCount));
  return result;
}

/// Reuses [TenderSource.wins]/[losses]/[historicalWinRatePercent] directly
/// — kept live by the `onTenderOpportunityOutcome` Cloud Function trigger
/// — rather than recomputing from opportunities client-side, so this
/// number always matches what the Source Workspace shows.
class TenderSourcePerformance {
  const TenderSourcePerformance({
    required this.source,
    required this.opportunityCount,
  });

  final TenderSource source;
  final int opportunityCount;
}

/// Ranked by win rate descending (sources with no recorded outcome sort
/// last, not first — an untested source isn't "best-performing" by
/// default), then by opportunity count as a tiebreak.
List<TenderSourcePerformance> computeSourcePerformanceRanking(
  List<TenderSource> sources,
  List<Opportunity> tenderOpportunities,
) {
  final opportunityCounts = <String, int>{};
  for (final o in tenderOpportunities) {
    final id = o.tenderSourceId;
    if (id == null) continue;
    opportunityCounts[id] = (opportunityCounts[id] ?? 0) + 1;
  }

  final result = [
    for (final s in sources)
      TenderSourcePerformance(
        source: s,
        opportunityCount: opportunityCounts[s.id] ?? 0,
      ),
  ];

  result.sort((a, b) {
    final aRate = a.source.historicalWinRatePercent;
    final bRate = b.source.historicalWinRatePercent;
    if (aRate == null && bRate == null) {
      return b.opportunityCount.compareTo(a.opportunityCount);
    }
    if (aRate == null) return 1;
    if (bRate == null) return -1;
    final cmp = bRate.compareTo(aRate);
    return cmp != 0 ? cmp : b.opportunityCount.compareTo(a.opportunityCount);
  });

  return result;
}
