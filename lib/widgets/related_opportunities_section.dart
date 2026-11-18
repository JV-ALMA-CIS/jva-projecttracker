import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/related_opportunity_triage.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/share_with_team_dialog.dart';

/// An AI recommendation's related opportunities — tappable, and triaged so
/// it's obvious which deserve attention: "worth a look" ones highlighted,
/// open ones normal, and closed / past-deadline ones greyed and folded away
/// (they still explain why the AI made the recommendation). Tapping opens a
/// quick preview with Pursue / Share / Not for us / Open.
class RelatedOpportunitiesSection extends ConsumerStatefulWidget {
  const RelatedOpportunitiesSection({super.key, required this.recommendation});

  final Recommendation recommendation;

  @override
  ConsumerState<RelatedOpportunitiesSection> createState() =>
      _RelatedOpportunitiesSectionState();
}

class _RelatedOpportunitiesSectionState
    extends ConsumerState<RelatedOpportunitiesSection> {
  bool _showReference = false;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final byId = <String, Opportunity>{
      for (final o
          in ref.watch(opportunitiesStreamProvider).value ??
              const <Opportunity>[])
        o.id: o,
    };
    final triaged = triageRelatedOpportunities(
      widget.recommendation,
      byId,
      DateTime.now(),
    );
    if (triaged.isEmpty) return const SizedBox.shrink();

    final active = triaged
        .where((t) => t.state != RelatedOpportunityState.reference)
        .toList();
    final reference = triaged
        .where((t) => t.state == RelatedOpportunityState.reference)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.relatedOpportunitiesLabel,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in active) _RelatedChip(triaged: t),
              if (_showReference)
                for (final t in reference) _RelatedChip(triaged: t),
            ],
          ),
          if (reference.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _showReference = !_showReference),
              child: Text(
                _showReference
                    ? strings.hideReferenceLabel
                    : strings.showReferenceLabel(reference.length),
              ),
            ),
        ],
      ),
    );
  }
}

/// One related opportunity: title, match %, and when it closes (or why it's
/// only for reference).
class _RelatedChip extends ConsumerWidget {
  const _RelatedChip({required this.triaged});

  final TriagedOpportunity triaged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final colors = Theme.of(context).colorScheme;
    final o = triaged.opportunity;
    final isWorth = triaged.state == RelatedOpportunityState.worthALook;
    final isReference = triaged.state == RelatedOpportunityState.reference;

    final title = o.title.length > 48
        ? '${o.title.substring(0, 47)}…'
        : o.title;
    final detail = isReference
        ? _referenceReason(strings, o)
        : _openDetail(strings, o);

    return ActionChip(
      avatar: Icon(
        isWorth
            ? Icons.star_rounded
            : isReference
            ? Icons.history_rounded
            : Icons.open_in_new_rounded,
        size: 16,
        color: isWorth ? colors.onPrimaryContainer : null,
      ),
      label: Text('$title · $detail'),
      tooltip: isWorth ? strings.worthALookLabel : null,
      backgroundColor: isWorth
          ? colors.primaryContainer
          : isReference
          ? colors.surfaceContainerHighest
          : null,
      labelStyle: TextStyle(
        color: isWorth
            ? colors.onPrimaryContainer
            : isReference
            ? colors.onSurfaceVariant.withValues(alpha: 0.7)
            : null,
        fontWeight: isWorth ? FontWeight.w600 : null,
      ),
      onPressed: () => showRelatedOpportunitySheet(context, o),
    );
  }
}

String _openDetail(AppStrings strings, Opportunity o) {
  final parts = <String>['${inboxScore(o)}%'];
  if (o.deadline != null) {
    parts.add(
      strings.closesInLabel(o.deadline!.difference(DateTime.now()).inDays),
    );
  }
  return parts.join(' · ');
}

String _referenceReason(AppStrings strings, Opportunity o) {
  final open =
      o.status == OpportunityStatus.discovered ||
      o.status == OpportunityStatus.reviewing;
  return open
      ? strings.pastDeadlineLabel
      : strings.opportunityStatusLabel(o.status);
}

/// Quick preview of a related opportunity without leaving the
/// recommendation: key facts, why it matched, and the next step.
Future<void> showRelatedOpportunitySheet(
  BuildContext context,
  Opportunity opportunity,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RelatedOpportunitySheet(opportunityId: opportunity.id),
  );
}

class _RelatedOpportunitySheet extends ConsumerWidget {
  const _RelatedOpportunitySheet({required this.opportunityId});

  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    // Live, so Pursue / Not for us are reflected immediately.
    final o = (ref.watch(opportunitiesStreamProvider).value ?? const [])
        .where((x) => x.id == opportunityId)
        .firstOrNull;
    if (o == null) return const SizedBox(height: 120);

    final canPursue = o.status == OpportunityStatus.discovered;
    final canDismiss =
        o.status == OpportunityStatus.discovered ||
        o.status == OpportunityStatus.reviewing;
    final reason = o.fitReasoning.trim().isNotEmpty
        ? o.fitReasoning.trim()
        : (o.description.trim().isNotEmpty ? o.description.trim() : null);

    Future<void> setStatus(OpportunityStatus status, String message) async {
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(opportunityServiceProvider).updateStatus(o.id, status);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(o.title, style: theme.textTheme.titleLarge),
            if (o.client != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                o.client!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Chip(label: Text('${inboxScore(o)}%')),
                Chip(label: Text(strings.opportunityKindLabel(o.kind))),
                Chip(label: Text(strings.opportunityStatusLabel(o.status))),
                if (o.deadline != null)
                  Chip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      o.deadline!.isAfter(DateTime.now())
                          ? strings.closesInLabel(
                              o.deadline!.difference(DateTime.now()).inDays,
                            )
                          : strings.pastDeadlineLabel,
                    ),
                  ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                strings.whyItMatchedLabel,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(reason, maxLines: 8, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (canPursue)
                  FilledButton.icon(
                    onPressed: () => setStatus(
                      OpportunityStatus.reviewing,
                      strings.pursuedMessage,
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(strings.pursueButton),
                  ),
                OutlinedButton.icon(
                  onPressed: () => showShareWithTeamDialog(context, o),
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(strings.shareWithTeamButton),
                ),
                if (canDismiss)
                  OutlinedButton.icon(
                    onPressed: () => setStatus(
                      OpportunityStatus.dismissed,
                      strings.notForUsMessage,
                    ),
                    icon: const Icon(Icons.close),
                    label: Text(strings.notForUsButton),
                  ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    pushSlideFade(
                      context,
                      OpportunityWorkspaceScreen(opportunityId: o.id),
                    );
                  },
                  icon: const Icon(Icons.open_in_full),
                  label: Text(strings.openFullDetailsButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
