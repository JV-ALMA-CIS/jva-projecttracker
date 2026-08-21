import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/executive_summary.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/services/executive_intelligence_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/distribution_bar_list.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/kpi_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// A fixed color per dashboard section, mapped to the platform's semantic
/// [AppStatusColors] roles based on what each section actually represents
/// (win/loss outcomes, risk watchlists, AI-generated content, or plain
/// informational metrics) — see the brief's "executives should understand
/// company performance within 30 seconds." Reused (not recreated) across
/// every section below.
class _SectionColors {
  static const summary = AppStatusColors.ai;
  static const active = AppStatusColors.info;
  static const pipelineValue = AppStatusColors.info;
  static const won = AppStatusColors.success;
  static const lost = AppStatusColors.danger;
  static const forecast = AppStatusColors.info;
  static const readiness = AppStatusColors.info;
  static const workload = AppStatusColors.info;
  static const submissions = AppStatusColors.warning;
  static const risk = AppStatusColors.danger;
  static const confidence = AppStatusColors.success;
}

/// A rotating palette for per-row breakdowns (stage/business unit/industry)
/// where the number of rows isn't fixed in advance.
const _kRowPalette = [
  Colors.indigo,
  Colors.teal,
  Colors.deepOrange,
  Colors.purple,
  Colors.blueGrey,
  Colors.cyan,
  Colors.brown,
  Colors.pink,
  Colors.lightGreen,
  Colors.amber,
  Colors.blue,
  Colors.deepPurple,
];

Color _severityColor(ExecutiveInsightSeverity s) => switch (s) {
  ExecutiveInsightSeverity.info => AppStatusColors.info,
  ExecutiveInsightSeverity.watch => AppStatusColors.warning,
  ExecutiveInsightSeverity.risk => AppStatusColors.danger,
};

/// The Executive Dashboard (Milestone 5.1) — the first screen of Phase 5
/// (Executive Intelligence & Analytics). Every number here is derived from
/// data already streamed elsewhere in the app (`executiveMetricsProvider`);
/// only the narrative AI Executive Summary panel involves a new read
/// (`executiveSummaryStreamProvider`) and a new Cloud Function call
/// (`generateExecutiveSummary`).
class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState
    extends ConsumerState<ExecutiveDashboardScreen> {
  bool _generating = false;

  Future<void> _regenerateSummary() async {
    setState(() => _generating = true);
    final strings = ref.read(appStringsProvider);
    try {
      await ref.read(executiveIntelligenceServiceProvider).generateSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.executiveSummarySucceeded)),
        );
      }
    } on ExecutiveIntelligenceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.executiveSummaryFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final metrics = ref.watch(executiveMetricsProvider);
    final summaryAsync = ref.watch(executiveSummaryStreamProvider);
    final businessUnits =
        ref.watch(businessUnitsStreamProvider).value ?? const [];
    final industries = ref.watch(industriesStreamProvider).value ?? const [];
    final stageCounts = ref.watch(pipelineStageCountsProvider);

    final businessUnitNames = {for (final b in businessUnits) b.id: b.name};
    final industryNames = {for (final i in industries) i.id: i.name};

    final numberFormat = NumberFormat.decimalPattern(strings.locale.toString());
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

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
              icon: Icons.insights_outlined,
              title: strings.executiveDashboardTitle,
              subtitle: strings.executiveDashboardSubtitle,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // --- AI Executive Summary ---
                _buildAiSummary(context, strings, summaryAsync, dateFormat),
                const SizedBox(height: AppSpacing.xl),

                // --- KPI row ---
                SectionHeader(
                  title: strings.pipelineSnapshotSectionTitle,
                  accentColor: _SectionColors.active,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiActiveOpportunities,
                        value: '${metrics.totalActiveOpportunities}',
                        icon: Icons.workspaces_outlined,
                        accentColor: _SectionColors.active,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiPipelineValue,
                        value: numberFormat.format(metrics.pipelineValue),
                        icon: Icons.account_balance_wallet_outlined,
                        accentColor: _SectionColors.pipelineValue,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiWinRate,
                        value: '${(metrics.winRate * 100).toStringAsFixed(0)}%',
                        icon: Icons.emoji_events_outlined,
                        accentColor: _SectionColors.won,
                        caption: strings.decidedOpportunitiesCaption(
                          metrics.wonCount + metrics.lostCount,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiLossRate,
                        value:
                            '${(metrics.lossRate * 100).toStringAsFixed(0)}%',
                        icon: Icons.trending_down,
                        accentColor: _SectionColors.lost,
                        caption: strings.decidedOpportunitiesCaption(
                          metrics.wonCount + metrics.lostCount,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiRevenueForecast,
                        value: numberFormat.format(metrics.revenueForecast),
                        icon: Icons.insights_outlined,
                        accentColor: _SectionColors.forecast,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiProposalsReadyForReview,
                        value: '${metrics.proposalsReadyForReview}',
                        icon: Icons.fact_check_outlined,
                        accentColor: _SectionColors.readiness,
                        caption: strings.ofTotalProposalsCaption(
                          metrics.totalProposals,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: strings.kpiAverageProposalReadiness,
                        value:
                            '${(metrics.averageProposalReadiness * 100).toStringAsFixed(0)}%',
                        icon: Icons.donut_large_outlined,
                        accentColor: _SectionColors.readiness,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // --- Distributions ---
                AdaptiveFieldRow(
                  children: [
                    _distributionCard(
                      context,
                      title: strings.sectionOpportunitiesByStage,
                      entries: [
                        for (final entry in stageCounts.entries)
                          if (entry.value > 0)
                            DistributionEntry(
                              label: strings.pipelineStageLabel(entry.key),
                              count: entry.value,
                              color:
                                  _kRowPalette[entry.key.index %
                                      _kRowPalette.length],
                            ),
                      ],
                    ),
                    _distributionCard(
                      context,
                      title: strings.sectionOpportunitiesByBusinessUnit,
                      entries: _namedEntries(
                        metrics.byBusinessUnitId,
                        businessUnitNames,
                      ),
                    ),
                    _distributionCard(
                      context,
                      title: strings.sectionOpportunitiesByIndustry,
                      entries: _namedEntries(
                        metrics.byIndustryId,
                        industryNames,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // --- Team workload ---
                _sectionCard(
                  context,
                  color: _SectionColors.workload,
                  title: strings.sectionTeamWorkload,
                  child: DistributionBarList(
                    entries: [
                      for (final entry in metrics.workloadByAssignee.entries)
                        DistributionEntry(
                          label: entry.key,
                          count: entry.value,
                          color: _SectionColors.workload,
                        ),
                      if (metrics.unassignedActiveCount > 0)
                        DistributionEntry(
                          label: strings.unassignedLabel,
                          count: metrics.unassignedActiveCount,
                          color: AppStatusColors.neutral,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // --- Watchlists ---
                _watchlistCard(
                  context,
                  strings: strings,
                  color: _SectionColors.submissions,
                  title: strings.sectionUpcomingSubmissions,
                  emptyMessage: strings.noUpcomingSubmissions,
                  opportunities: metrics.upcomingSubmissions,
                  trailingBuilder: (o) => Text(
                    strings.daysUntilDeadlineLabel(
                      o.deadline!.difference(DateTime.now()).inDays,
                    ),
                    style: const TextStyle(color: _SectionColors.submissions),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _watchlistCard(
                  context,
                  strings: strings,
                  color: _SectionColors.risk,
                  title: strings.sectionHighRiskOpportunities,
                  emptyMessage: strings.noHighRiskOpportunities,
                  opportunities: metrics.highRiskOpportunities,
                ),
                const SizedBox(height: AppSpacing.lg),
                _watchlistCard(
                  context,
                  strings: strings,
                  color: _SectionColors.confidence,
                  title: strings.sectionHighConfidenceOpportunities,
                  emptyMessage: strings.noHighConfidenceOpportunities,
                  opportunities: metrics.highConfidenceOpportunities,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DistributionEntry> _namedEntries(
    Map<String, int> counts,
    Map<String, String> names,
  ) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (var i = 0; i < sorted.length; i++)
        DistributionEntry(
          label: names[sorted[i].key] ?? sorted[i].key,
          count: sorted[i].value,
          color: _kRowPalette[i % _kRowPalette.length],
        ),
    ];
  }

  Widget _buildAiSummary(
    BuildContext context,
    AppStrings strings,
    AsyncValue<ExecutiveSummary> summaryAsync,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);

    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _SectionColors.summary, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: _SectionColors.summary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      strings.aiExecutiveSummaryTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _generating ? null : _regenerateSummary,
                    icon: _generating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(strings.regenerateSummaryButton),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              summaryAsync.when(
                data: (summary) {
                  if (summary.isEmpty) {
                    return Text(strings.neverGeneratedSummaryMessage);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.narrative),
                      if (summary.generatedAt != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          strings.lastGeneratedLabel(
                            dateFormat.format(summary.generatedAt!),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (summary.insights.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        for (final insight in summary.insights)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _severityColor(insight.severity),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        insight.title,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      Text(
                                        insight.reasoning,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(strings.errorPrefix(e)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distributionCard(
    BuildContext context, {
    required String title,
    required List<DistributionEntry> entries,
  }) {
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.md),
              DistributionBarList(entries: entries),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required Color color,
    required String title,
    required Widget child,
  }) {
    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _watchlistCard(
    BuildContext context, {
    required AppStrings strings,
    required Color color,
    required String title,
    required String emptyMessage,
    required List<Opportunity> opportunities,
    Widget Function(Opportunity)? trailingBuilder,
  }) {
    return _sectionCard(
      context,
      color: color,
      title: title,
      child: opportunities.isEmpty
          ? Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < opportunities.length; i++)
                  FadeSlideIn(
                    index: i,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: FitScoreBadge(
                        percent: opportunities[i].fitScorePercent,
                        size: 32,
                      ),
                      title: Text(opportunities[i].title),
                      subtitle: Text(
                        opportunities[i].client ?? opportunities[i].sourceUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: trailingBuilder?.call(opportunities[i]),
                      onTap: () => pushSlideFade(
                        context,
                        OpportunityWorkspaceScreen(
                          opportunityId: opportunities[i].id,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
