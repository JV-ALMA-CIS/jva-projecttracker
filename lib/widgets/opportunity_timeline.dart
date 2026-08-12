import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Reusable "Pipeline History" list for a single opportunity — every stage
/// transition, most recent first (see
/// [OpportunityEventService.watchByOpportunity]). Used by
/// [OpportunityPipelineScreen] today; kept as a standalone widget rather
/// than inlined since a chronological timeline is a natural fit for a
/// future opportunity detail screen too.
class OpportunityTimeline extends ConsumerWidget {
  const OpportunityTimeline({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final eventsAsync = ref.watch(
      opportunityEventsByOpportunityProvider(opportunityId),
    );

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(strings.noEventsYet),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final event in events)
              _TimelineEntry(event: event, strings: strings),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(strings.errorPrefix(error)),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event, required this.strings});

  final OpportunityEvent event;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.description.isNotEmpty)
                  Text(event.description, style: theme.textTheme.bodySmall),
                Text(
                  [
                    dateFormat.format(event.createdAt),
                    if (event.createdBy != null && event.createdBy!.isNotEmpty)
                      event.createdBy!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
