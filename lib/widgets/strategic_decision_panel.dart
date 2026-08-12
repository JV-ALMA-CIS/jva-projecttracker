import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// The human half of Strategic Review: separate from, and never overwriting,
/// [Opportunity.executiveRecommendation] (the AI's advisory output). AI
/// recommends; a human decides — this panel records that decision as its
/// own persisted fact (`humanDecision`/`humanDecisionReason`/
/// `humanDecisionBy`/`humanDecisionAt`), including the case where the human
/// deliberately disagrees with the AI. Nothing here gates Proposal or
/// Submission creation — whether it should is an open product decision,
/// not assumed by this widget.
class StrategicDecisionPanel extends ConsumerStatefulWidget {
  const StrategicDecisionPanel({super.key, required this.opportunity});

  final Opportunity opportunity;

  @override
  ConsumerState<StrategicDecisionPanel> createState() =>
      _StrategicDecisionPanelState();
}

class _StrategicDecisionPanelState
    extends ConsumerState<StrategicDecisionPanel> {
  StrategicReviewRecommendation? _selected;
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _record(AppStrings strings) async {
    final decision = _selected;
    if (decision == null) return;
    setState(() => _saving = true);

    final actor = ref.read(authStateChangesProvider).value?.email;
    await ref
        .read(opportunityServiceProvider)
        .recordStrategicDecision(
          opportunityId: widget.opportunity.id,
          decision: decision,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
          decidedBy: actor,
        );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _selected = null;
      _reasonController.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.decisionRecordedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final opportunity = widget.opportunity;
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());
    final recorded = opportunity.humanDecision;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.yourDecisionLabel),
        if (recorded != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          strings.strategicReviewRecommendationLabel(recorded),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (opportunity.executiveRecommendation != null)
                        Icon(
                          recorded == opportunity.executiveRecommendation
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          size: 18,
                          color: recorded == opportunity.executiveRecommendation
                              ? AppStatusColors.success
                              : AppStatusColors.warning,
                        ),
                    ],
                  ),
                  if (opportunity.executiveRecommendation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      recorded == opportunity.executiveRecommendation
                          ? strings.decisionAgreesWithAiLabel
                          : strings.decisionOverridesAiLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (opportunity.humanDecisionReason?.isNotEmpty ?? false) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(opportunity.humanDecisionReason!),
                  ],
                  if (opportunity.humanDecisionAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      strings.decisionRecordedByLabel(
                        opportunity.humanDecisionBy ?? '—',
                        dateFormat.format(opportunity.humanDecisionAt!),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              strings.noDecisionRecordedYetMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in StrategicReviewRecommendation.values)
              ChoiceChip(
                label: Text(strings.strategicReviewRecommendationLabel(option)),
                selected: _selected == option,
                onSelected: (selected) =>
                    setState(() => _selected = selected ? option : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            labelText: strings.decisionReasonFieldLabel,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _selected == null || _saving
              ? null
              : () => _record(strings),
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.recordDecisionButton),
        ),
      ],
    );
  }
}
