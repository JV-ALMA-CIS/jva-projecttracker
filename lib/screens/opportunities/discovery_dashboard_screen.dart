import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';
import 'package:jva_projecttracker/screens/opportunities/tender_analytics_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/tender_sources_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/tender_discovery_metrics.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

Color _statusColor(ColorScheme scheme, TenderSyncRunStatus status) =>
    switch (status) {
      TenderSyncRunStatus.running => scheme.primary,
      TenderSyncRunStatus.completed => AppStatusColors.success,
      TenderSyncRunStatus.failed => scheme.error,
    };

IconData _statusIcon(TenderSyncRunStatus status) => switch (status) {
  TenderSyncRunStatus.running => Icons.hourglass_top,
  TenderSyncRunStatus.completed => Icons.check_circle_outline,
  TenderSyncRunStatus.failed => Icons.error_outline,
};

Color _healthColor(ColorScheme scheme, int? score) {
  if (score == null) return scheme.outline;
  if (score >= 80) return AppStatusColors.success;
  if (score >= 50) return AppStatusColors.warning;
  return scheme.error;
}

/// The Discovery Engine's executive overview (Milestone 3.8b) — read-only,
/// entirely derived from [tenderDiscoveryMetricsProvider] /
/// [recentTenderSyncRunsProvider] (no new Firestore reads of its own).
///
/// Deliberately has no source-management actions yet: Tender Source
/// admin CRUD and the per-source drill-down land in Milestone 3.8c (Source
/// Workspace). Until then this screen is legitimately mostly-empty for any
/// project with no `tenderSources` configured, which the empty state below
/// makes explicit rather than showing a confusing zeroed-out dashboard.
class DiscoveryDashboardScreen extends ConsumerWidget {
  const DiscoveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.discoveryDashboardTitle)),
      body: const DiscoveryDashboardBody(),
    );
  }
}

/// The Discovery Dashboard's content with no [Scaffold]/[AppBar] of its own
/// — used both by [DiscoveryDashboardScreen] (standalone) and as the
/// Opportunities hub's Discovery tab. The two AppBar icon actions that used
/// to open Tender Analytics/Sources are now two large colored cards at the
/// top instead — full-page drill-downs are still fine for genuinely
/// separate destinations, they just shouldn't be tiny unlabeled toolbar
/// icons.
class DiscoveryDashboardBody extends ConsumerWidget {
  const DiscoveryDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final metrics = ref.watch(tenderDiscoveryMetricsProvider);
    final recentRuns = ref.watch(recentTenderSyncRunsProvider);

    if (metrics.totalSources == 0) {
      return EmptyState(
        icon: Icons.travel_explore_outlined,
        title: strings.noTenderSourcesConfiguredMessage,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: _DrillDownCard(
                icon: Icons.settings_input_antenna_outlined,
                label: strings.tenderSourcesTitle,
                color: Colors.deepPurple,
                onTap: () =>
                    pushSlideFade(context, const TenderSourcesScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DrillDownCard(
                icon: Icons.query_stats_outlined,
                label: strings.tenderAnalyticsTitle,
                color: Colors.teal,
                onTap: () =>
                    pushSlideFade(context, const TenderAnalyticsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _HealthSection(metrics: metrics, strings: strings),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: strings.discoveryHealthLabel,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        _KpiGrid(metrics: metrics, strings: strings),
        const SizedBox(height: AppSpacing.xl),
        _SyncTimingSection(metrics: metrics, strings: strings),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: strings.recentSyncActivityLabel,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (recentRuns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(strings.noSyncDataYetMessage),
          )
        else
          ...recentRuns.asMap().entries.map(
            (entry) => FadeSlideIn(
              index: entry.key,
              child: _RecentSyncTile(run: entry.value),
            ),
          ),
      ],
    );
  }
}

class _DrillDownCard extends StatelessWidget {
  const _DrillDownCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: color.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.metrics, required this.strings});

  final TenderDiscoveryMetrics metrics;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = metrics.overallHealthScore;

    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _HealthRing(score: score),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.discoveryHealthLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${strings.activeSourcesLabel}: '
                      '${metrics.activeSources} ${strings.outOfSourcesLabel} '
                      '${metrics.totalSources}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (metrics.averageWinRatePercent != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${strings.averageWinRateLabel}: '
                        '${metrics.averageWinRatePercent!.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple circular health indicator. Self-contained here rather than
/// added to widgets/ as a shared component — no other screen needs a
/// generic progress ring yet (Milestone 3.8c's Source Workspace can
/// promote this to widgets/ if it turns out to need the same visual).
class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _healthColor(theme.colorScheme, score);

    return SizedBox(
      height: 72,
      width: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score == null ? null : score! / 100,
            strokeWidth: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            score == null ? '—' : '$score',
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics, required this.strings});

  final TenderDiscoveryMetrics metrics;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _KpiCardData(
        icon: Icons.check_circle_outline,
        label: strings.activeSourcesLabel,
        value: '${metrics.activeSources}',
        color: AppStatusColors.success,
      ),
      _KpiCardData(
        icon: Icons.cloud_off_outlined,
        label: strings.offlineSourcesLabel,
        value: '${metrics.offlineSources}',
        color: theme.colorScheme.outline,
      ),
      _KpiCardData(
        icon: Icons.error_outline,
        label: strings.syncErrorsLabel,
        value: '${metrics.sourcesWithErrors}',
        color: theme.colorScheme.error,
      ),
      _KpiCardData(
        icon: Icons.file_download_outlined,
        label: strings.importedTodayLabel,
        value: '${metrics.opportunitiesImportedToday}',
        color: theme.colorScheme.primary,
      ),
      _KpiCardData(
        icon: Icons.pending_actions_outlined,
        label: strings.awaitingAiReviewLabel,
        value: '${metrics.opportunitiesAwaitingReview}',
        color: AppStatusColors.warning,
      ),
      _KpiCardData(
        icon: Icons.content_copy_outlined,
        label: strings.duplicateOpportunitiesLabel,
        value: '${metrics.duplicateOpportunityCount}',
        color: theme.colorScheme.tertiary,
      ),
      _KpiCardData(
        icon: Icons.auto_awesome_outlined,
        label: strings.aiRecommendedLabel,
        value: '${metrics.aiRecommendedOpportunityCount}',
        color: theme.colorScheme.secondary,
      ),
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
          childAspectRatio: 1.5,
          children: [for (final c in cards) _KpiCard(data: c)],
        );
      },
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.color, size: 22),
              const SizedBox(height: AppSpacing.sm),
              Text(
                data.value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: data.color,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                data.label,
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
    );
  }
}

class _SyncTimingSection extends StatelessWidget {
  const _SyncTimingSection({required this.metrics, required this.strings});

  final TenderDiscoveryMetrics metrics;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return Row(
      children: [
        Expanded(
          child: _TimingTile(
            icon: Icons.history,
            label: strings.lastSynchronizationLabel,
            value: metrics.lastSyncAt == null
                ? strings.noSyncDataYetMessage
                : dateFormat.format(metrics.lastSyncAt!),
            theme: theme,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _TimingTile(
            icon: Icons.schedule,
            label: strings.nextSynchronizationLabel,
            value: metrics.nextScheduledSyncAt == null
                ? strings.noSyncDataYetMessage
                : dateFormat.format(metrics.nextScheduledSyncAt!),
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _TimingTile extends StatelessWidget {
  const _TimingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSyncTile extends ConsumerWidget {
  const _RecentSyncTile({required this.run});

  final TenderSyncRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: Icon(
            _statusIcon(run.status),
            color: _statusColor(theme.colorScheme, run.status),
          ),
          title: Text(run.sourceName),
          subtitle: Text(
            '${strings.tenderDiscoveryMethodLabel(run.discoveryMethod)} · '
            '${dateFormat.format(run.startedAt)}',
          ),
          trailing: run.status == TenderSyncRunStatus.completed
              ? Text('+${run.opportunitiesCreated}')
              : Chip(
                  label: Text(strings.tenderSyncRunStatusLabel(run.status)),
                  visualDensity: VisualDensity.compact,
                ),
        ),
      ),
    );
  }
}
