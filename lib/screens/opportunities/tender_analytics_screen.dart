import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/tender_analytics.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Engine-wide Tender Analytics (Milestone 3.8d). Every number here is
/// derived from data already live elsewhere (opportunities, tender
/// sources) — see providers_ADDITIONS_for_tender_analytics.dart — except
/// `TenderSource.wins/losses/historicalWinRatePercent`, which are now kept
/// live by the `onTenderOpportunityOutcome` Cloud Function trigger rather
/// than recomputed here, so this screen and the Source Workspace never
/// disagree with each other.
class TenderAnalyticsScreen extends ConsumerWidget {
  const TenderAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final summary = ref.watch(tenderAnalyticsSummaryProvider);

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: PageHeader(
              icon: Icons.query_stats_outlined,
              title: strings.tenderAnalyticsTitle,
            ),
          ),
          Expanded(
            child: summary.discovered == 0
                ? EmptyState(
                    icon: Icons.query_stats_outlined,
                    title: strings.noAnalyticsDataYetMessage,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      _SummaryGrid(summary: summary, strings: strings),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(title: strings.monthlyTrendLabel),
                      const SizedBox(height: AppSpacing.sm),
                      const _MonthlyTrendChart(),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(title: strings.bestPerformingSourcesLabel),
                      const SizedBox(height: AppSpacing.sm),
                      const _SourceRanking(),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(
                        title: strings.bestPerformingBusinessUnitsLabel,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _BusinessUnitRanking(),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(title: strings.bestPerformingSectorsLabel),
                      const SizedBox(height: AppSpacing.sm),
                      const _SectorRanking(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.strings});

  final TenderAnalyticsSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyValue = summary.totalContractValueWon == 0
        ? '—'
        : summary.totalContractValueWon.toStringAsFixed(0);

    final labels = <String>[
      strings.discoveredLabel,
      strings.pursuedLabel,
      strings.winsLabel,
      strings.lossesLabel,
      strings.winRateLabel,
      strings.totalContractValueWonLabel,
      strings.averageAiConfidenceLabel,
    ];
    final values = <String>[
      '${summary.discovered}',
      '${summary.pursued}',
      '${summary.wins}',
      '${summary.losses}',
      summary.winRatePercent == null
          ? '—'
          : '${summary.winRatePercent!.toStringAsFixed(0)}%',
      currencyValue,
      summary.averageAiConfidence == null
          ? '—'
          : summary.averageAiConfidence!.toStringAsFixed(0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.6,
          children: [
            for (var i = 0; i < labels.length; i++)
              HoverLift(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(values[i], style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          labels[i],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A minimal bar chart — self-contained here rather than pulling in a
/// charting package, since this is the only chart in the Discovery Engine
/// so far (see discovery_dashboard_screen.dart's HealthRing for the same
/// "no shared widget until a second use case needs it" call).
class _MonthlyTrendChart extends ConsumerWidget {
  const _MonthlyTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(tenderMonthlyOpportunityTrendProvider);
    final theme = Theme.of(context);
    final maxCount = trend.map((m) => m.count).fold(0, (a, b) => a > b ? a : b);

    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in trend)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${point.count}',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: maxCount == 0
                                ? 4
                                : 8 + (point.count / maxCount) * 70,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${point.month.month}/${point.month.year % 100}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceRanking extends ConsumerWidget {
  const _SourceRanking();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final ranking = ref.watch(tenderSourcePerformanceRankingProvider).take(5);

    return Column(
      children: [
        for (final entry in ranking)
          HoverLift(
            child: Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(entry.source.name),
                subtitle: Text('${entry.opportunityCount} opportunities'),
                trailing: Text(
                  entry.source.historicalWinRatePercent == null
                      ? strings.noOutcomeRecordedYetMessage
                      : '${entry.source.historicalWinRatePercent!.toStringAsFixed(0)}%',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BusinessUnitRanking extends ConsumerWidget {
  const _BusinessUnitRanking();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(tenderBusinessUnitPerformanceProvider).take(5);
    final businessUnits =
        ref.watch(businessUnitsStreamProvider).value ?? const [];
    final nameById = {for (final u in businessUnits) u.id: u.name};

    return Column(
      children: [
        for (final entry in ranking)
          HoverLift(
            child: Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(
                  nameById[entry.businessUnitId] ?? entry.businessUnitId,
                ),
                trailing: Text('${entry.opportunityCount} · ${entry.wins} won'),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectorRanking extends ConsumerWidget {
  const _SectorRanking();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(tenderSectorPerformanceProvider).take(8);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in ranking)
          Chip(label: Text('${entry.sector} (${entry.opportunityCount})')),
      ],
    );
  }
}
