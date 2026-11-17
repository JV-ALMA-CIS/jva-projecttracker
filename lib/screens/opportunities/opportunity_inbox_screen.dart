import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';
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
///
/// Pre-sorted so nobody has to filter by hand: a tab per kind (Tenders /
/// Grants & Calls / Programmes) with counts, and for tenders one chip per
/// business unit. Each person's last tab/chip is remembered
/// ([inboxViewProvider]); items are best match first, and closed ones drop
/// out automatically ([inboxOpportunitiesProvider]).
class OpportunityInboxBody extends ConsumerWidget {
  const OpportunityInboxBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final inbox = ref.watch(inboxOpportunitiesProvider);
    final duplicates = ref.watch(opportunityDuplicatesProvider);
    final view = ref.watch(inboxViewProvider);
    final controller = ref.read(inboxViewProvider.notifier);

    if (inbox.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: strings.inboxEmptyMessage,
      );
    }

    final kindCounts = inboxKindCounts(inbox);
    final ofKind = inboxSlice(inbox, kind: view.kind);

    // Business-unit chips only for tenders — grants/programmes are few
    // enough to scan directly.
    final showBusinessUnits = view.kind == OpportunityKind.tender;
    final businessUnits = showBusinessUnits
        ? sortBusinessUnitsForChips(
            ref.watch(businessUnitsStreamProvider).value ?? const [],
          )
        : const <BusinessUnit>[];
    final selectedBu = businessUnits
        .where((b) => b.id == view.businessUnitId)
        .firstOrNull;
    final buFilter = selectedBu == null
        ? const OpportunityBuFilter.all()
        : OpportunityBuFilter.specific(selectedBu.id, selectedBu.name);
    final visible = inboxSlice(inbox, kind: view.kind, businessUnit: buFilter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: SegmentedButton<OpportunityKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in OpportunityKind.values)
                ButtonSegment(
                  value: kind,
                  label: Text(
                    '${strings.opportunityKindLabel(kind)} (${kindCounts[kind]})',
                  ),
                ),
            ],
            selected: {view.kind},
            onSelectionChanged: (s) => controller.setKind(s.first),
          ),
        ),
        if (showBusinessUnits && businessUnits.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(
                      '${strings.inboxAllBusinessUnits} (${ofKind.length})',
                    ),
                    selected: selectedBu == null,
                    onSelected: (_) => controller.setBusinessUnit(null),
                  ),
                ),
                for (final bu in businessUnits)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(
                        '${bu.name} (${inboxSlice(inbox, kind: view.kind, businessUnit: OpportunityBuFilter.specific(bu.id, bu.name)).length})',
                      ),
                      selected: selectedBu?.id == bu.id,
                      onSelected: (_) => controller.setBusinessUnit(bu.id),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: strings.inboxSliceEmpty,
                  compact: true,
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final opportunity = visible[i];
                    return FadeSlideIn(
                      index: i,
                      child: _InboxTile(
                        opportunity: opportunity,
                        duplicateOf: duplicates[opportunity.id],
                      ),
                    );
                  },
                ),
        ),
      ],
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
                      FitScoreBadge(percent: inboxScore(opportunity)),
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
                  if (opportunity.deadline != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Builder(
                      builder: (context) {
                        final days = opportunity.deadline!
                            .difference(DateTime.now())
                            .inDays;
                        final urgent = days <= 3;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: urgent ? AppStatusColors.danger : null,
                            ),
                            label: Text(strings.closesInLabel(days)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
                    ),
                  ],
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
