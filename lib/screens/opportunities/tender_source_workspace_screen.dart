import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';
import 'package:jva_projecttracker/services/tender_sync_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:logger/logger.dart';

final _log = Logger();

Color _statusColor(ColorScheme scheme, TenderSourceStatus status) =>
    switch (status) {
      TenderSourceStatus.active => AppStatusColors.success,
      TenderSourceStatus.paused => scheme.outline,
      TenderSourceStatus.offline => AppStatusColors.warning,
      TenderSourceStatus.error => scheme.error,
    };

Color _runStatusColor(ColorScheme scheme, TenderSyncRunStatus status) =>
    switch (status) {
      TenderSyncRunStatus.running => scheme.primary,
      TenderSyncRunStatus.completed => AppStatusColors.success,
      TenderSyncRunStatus.failed => scheme.error,
    };

IconData _runStatusIcon(TenderSyncRunStatus status) => switch (status) {
  TenderSyncRunStatus.running => Icons.hourglass_top,
  TenderSyncRunStatus.completed => Icons.check_circle_outline,
  TenderSyncRunStatus.failed => Icons.error_outline,
};

/// Per-source drill-down (Milestone 3.8c, Import History closed out in
/// 3.8d once `Opportunity.tenderSourceId` became available). Covers
/// Organization Profile, Sync History, Error History, AI Quality Score,
/// Historical Win Rate, Avg. Opportunities/Month, and — as of 3.8d — real
/// Import History and a monthly trend, both derived from
/// [tenderSourceOpportunitiesProvider] rather than a new Firestore query.
class TenderSourceWorkspaceScreen extends ConsumerWidget {
  const TenderSourceWorkspaceScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final sourceAsync = ref.watch(tenderSourceByIdProvider(sourceId));

    return Scaffold(
      appBar: AppBar(title: Text(strings.tenderSourcesTitle)),
      body: sourceAsync.when(
        data: (source) => source == null
            ? const SizedBox.shrink()
            : _WorkspaceBody(source: source, strings: strings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
      ),
    );
  }
}

class _WorkspaceBody extends ConsumerStatefulWidget {
  const _WorkspaceBody({required this.source, required this.strings});

  final TenderSource source;
  final AppStrings strings;

  @override
  ConsumerState<_WorkspaceBody> createState() => _WorkspaceBodyState();
}

class _WorkspaceBodyState extends ConsumerState<_WorkspaceBody> {
  bool _running = false;

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final created = await ref
          .read(tenderSyncServiceProvider)
          .runSource(widget.source.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.strings.runCreatedOpportunities(created)),
          ),
        );
      }
    } on TenderSyncException catch (e) {
      _log.e('Tender source sync failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.strings.errorPrefix(e))));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _confirmDelete() async {
    final strings = widget.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteSourceButton),
        content: Text(strings.deleteSourceConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.deleteSourceButton),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(tenderSourceServiceProvider).delete(widget.source.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final source = widget.source;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();
    final syncRuns = ref.watch(tenderSyncRunsBySourceProvider(source.id));

    final monthsSinceCreated =
        (DateTime.now().difference(source.createdAt).inDays / 30).clamp(
          1,
          double.infinity,
        );
    final avgPerMonth = source.opportunitiesImported / monthsSinceCreated;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // --- Organization Profile ---
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _statusColor(
                          theme.colorScheme,
                          source.status,
                        ),
                        radius: 6,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          source.name,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Chip(
                        label: Text(
                          strings.tenderSourceStatusLabel(source.status),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    source.organization,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Chip(
                        label: Text(
                          strings.tenderSourceCategoryLabel(source.category),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          strings.tenderDiscoveryMethodLabel(
                            source.discoveryMethod,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (source.country != null)
                        Chip(
                          avatar: const Icon(Icons.flag_outlined, size: 16),
                          label: Text(source.country!),
                          visualDensity: VisualDensity.compact,
                        ),
                      for (final tag in source.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${strings.sourceCreatedLabel}: '
                    '${dateFormat.format(source.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // --- Actions ---
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed:
                  source.discoveryMethod == TenderDiscoveryMethod.manual ||
                      _running
                  ? null
                  : _runNow,
              icon: _running
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(strings.runNowButton),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final service = ref.read(tenderSourceServiceProvider);
                if (source.status == TenderSourceStatus.paused) {
                  service.resume(source.id);
                } else {
                  service.pause(source.id);
                }
              },
              icon: Icon(
                source.status == TenderSourceStatus.paused
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                size: 18,
              ),
              label: Text(
                source.status == TenderSourceStatus.paused
                    ? strings.resumeSourceButton
                    : strings.pauseSourceButton,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              label: Text(
                strings.deleteSourceButton,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Scoring ---
        SectionHeader(title: strings.discoveryHealthLabel),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: strings.aiQualityScoreLabel,
                value: source.aiQualityScore == null
                    ? strings.noAiQualityScoreYetMessage
                    : '${source.aiQualityScore}',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: strings.historicalWinRateLabel,
                value: source.historicalWinRatePercent == null
                    ? strings.noAiQualityScoreYetMessage
                    : '${source.historicalWinRatePercent!.toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: strings.opportunitiesImportedLabel,
                value: '${source.opportunitiesImported}',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: strings.avgOpportunitiesPerMonthLabel,
                value: avgPerMonth.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Import History ---
        SectionHeader(title: strings.importHistoryLabel),
        const SizedBox(height: AppSpacing.sm),
        Builder(
          builder: (context) {
            final imported = ref.watch(
              tenderSourceOpportunitiesProvider(source.id),
            );
            if (imported.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(strings.noAnalyticsDataYetMessage),
              );
            }
            final sorted = [...imported]
              ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
            return Column(
              children: [
                for (final o in sorted.take(10))
                  HoverLift(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(o.title),
                        subtitle: Text(dateFormat.format(o.discoveredAt)),
                        trailing: Text(
                          strings.opportunityStatusLabel(o.status),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Sync / Error History ---
        SectionHeader(title: strings.syncHistoryLabel),
        const SizedBox(height: AppSpacing.sm),
        syncRuns.when(
          data: (runs) {
            if (runs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(strings.noSyncDataYetMessage),
              );
            }
            return Column(
              children: [
                for (final run in runs)
                  _SyncRunTile(run: run, strings: strings),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(strings.errorPrefix(e)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
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

class _SyncRunTile extends StatelessWidget {
  const _SyncRunTile({required this.run, required this.strings});

  final TenderSyncRun run;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: Icon(
            _runStatusIcon(run.status),
            color: _runStatusColor(theme.colorScheme, run.status),
          ),
          title: Text(dateFormat.format(run.startedAt)),
          subtitle: Text(
            '${strings.tenderSyncTriggerLabel(run.trigger)} · '
            '+${run.opportunitiesCreated} · '
            '${run.duplicatesSkipped} dup',
          ),
          trailing:
              run.status == TenderSyncRunStatus.failed &&
                  run.errorMessage != null
              ? Tooltip(
                  message: run.errorMessage!,
                  child: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                )
              : Chip(
                  label: Text(strings.tenderSyncRunStatusLabel(run.status)),
                  visualDensity: VisualDensity.compact,
                ),
        ),
      ),
    );
  }
}
