import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';

/// The Opportunity Inbox — a triage-focused view of opportunities still
/// awaiting a decision (`status == discovered`), regardless of which
/// discovery source produced them. Accept/Ignore/Archive each move an item
/// out of the Inbox by changing its `status`; opening the workspace reuses
/// the unmodified Milestone 2 `OpportunityWorkspaceScreen`. See the
/// Opportunity Discovery Engine (Milestone 3.7).
class OpportunityInboxScreen extends ConsumerWidget {
  const OpportunityInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.inboxTitle)),
      body: const OpportunityInboxBody(),
    );
  }
}

/// The Inbox's content with no [Scaffold]/[AppBar] of its own — used both
/// by [OpportunityInboxScreen] (standalone) and as the Opportunities hub's
/// Inbox tab.
class OpportunityInboxBody extends ConsumerWidget {
  const OpportunityInboxBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final inbox = ref.watch(inboxOpportunitiesProvider);
    final duplicates = ref.watch(opportunityDuplicatesProvider);

    return inbox.isEmpty
        ? EmptyState(
            icon: Icons.inbox_outlined,
            title: strings.inboxEmptyMessage,
          )
        : ListView.builder(
            itemCount: inbox.length,
            itemBuilder: (context, i) {
              final opportunity = inbox[i];
              return FadeSlideIn(
                index: i,
                child: _InboxTile(
                  opportunity: opportunity,
                  duplicateOf: duplicates[opportunity.id],
                ),
              );
            },
          );
  }
}

/// A color for how long an opportunity has waited untouched in the Inbox —
/// fresh/aging/stale — so triage priority reads at a glance instead of
/// requiring everything to be opened.
Color _waitingColor(Opportunity opportunity) {
  final days = DateTime.now().difference(opportunity.discoveredAt).inDays;
  if (days >= 5) return AppStatusColors.danger;
  if (days >= 2) return AppStatusColors.warning;
  return AppStatusColors.success;
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.opportunity, this.duplicateOf});

  final Opportunity opportunity;
  final Opportunity? duplicateOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final waitingColor = _waitingColor(opportunity);

    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: waitingColor, width: 4)),
          ),
          child: InkWell(
            onTap: () => pushSlideFade(
              context,
              OpportunityWorkspaceScreen(opportunityId: opportunity.id),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FitScoreBadge(percent: opportunity.fitScorePercent),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opportunity.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              opportunity.client ?? opportunity.sourceUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.circle, size: 10, color: waitingColor),
                    ],
                  ),
                  if (duplicateOf != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.input),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.content_copy_outlined,
                            size: 16,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              strings.possibleDuplicateOf(duplicateOf!.title),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(opportunityServiceProvider)
                            .updateStatus(
                              opportunity.id,
                              OpportunityStatus.reviewing,
                            ),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(strings.acceptButton),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(opportunityServiceProvider)
                            .updateStatus(
                              opportunity.id,
                              OpportunityStatus.dismissed,
                            ),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(strings.ignoreButton),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(opportunityServiceProvider)
                            .updateStatus(
                              opportunity.id,
                              OpportunityStatus.archived,
                            ),
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: Text(strings.archiveButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
