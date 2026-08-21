import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';

Color _statusColor(ColorScheme scheme, DiscoveryRunStatus status) =>
    switch (status) {
      DiscoveryRunStatus.running => scheme.primary,
      DiscoveryRunStatus.completed => AppStatusColors.success,
      DiscoveryRunStatus.failed => scheme.error,
    };

IconData _statusIcon(DiscoveryRunStatus status) => switch (status) {
  DiscoveryRunStatus.running => Icons.hourglass_top,
  DiscoveryRunStatus.completed => Icons.check_circle_outline,
  DiscoveryRunStatus.failed => Icons.error_outline,
};

/// A reverse-chronological audit trail of every [DiscoveryRun] — the
/// Discovery History screen. See the Opportunity Discovery Engine
/// (Milestone 3.7).
class DiscoveryHistoryScreen extends ConsumerWidget {
  const DiscoveryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final runs = ref.watch(discoveryRunsStreamProvider);

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
              icon: Icons.history,
              title: strings.discoveryHistoryTitle,
              accentColor: AppStatusColors.info,
            ),
          ),
          Expanded(
            child: runs.when(
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.history,
                    title: strings.noDiscoveryRunsMessage,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    return FadeSlideIn(
                      index: i,
                      child: _RunTile(run: list[i]),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.run});

  final DiscoveryRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final locale = strings.locale.languageCode;
    final dateText = DateFormat.yMMMd(locale).add_Hm().format(run.startedAt);

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: ExpansionTile(
          leading: Icon(
            _statusIcon(run.status),
            color: _statusColor(theme.colorScheme, run.status),
          ),
          title: Text(run.sourceName),
          subtitle: Text(
            '${strings.discoverySourceTypeLabel(run.sourceType)} · $dateText',
          ),
          trailing: Chip(
            label: Text(strings.discoveryRunStatusLabel(run.status)),
            visualDensity: VisualDensity.compact,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.discoveryRunSummary(
                      run.opportunitiesCreated,
                      run.duplicatesSkipped,
                    ),
                  ),
                  Text(strings.discoveryRunTriggerLabel(run.trigger)),
                  if (run.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      run.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
