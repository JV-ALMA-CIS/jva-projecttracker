import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Colour and icon for a grant's eligibility.
(Color, IconData) eligibilityStyle(GrantEligibility e) => switch (e) {
  GrantEligibility.eligible => (
    AppStatusColors.success,
    Icons.verified_outlined,
  ),
  GrantEligibility.needsPartner => (
    AppStatusColors.warning,
    Icons.handshake_outlined,
  ),
  GrantEligibility.notEligible => (AppStatusColors.danger, Icons.block),
  GrantEligibility.unclear => (AppStatusColors.neutral, Icons.help_outline),
};

/// "Can we apply?" at a glance for a grant/call/programme: an eligibility
/// chip, the funding amount, and the one-line reason (Synnefa-style), from
/// the server's eligibility check. Renders nothing for tenders or grants
/// not checked yet.
class GrantEligibilitySummary extends ConsumerWidget {
  const GrantEligibilitySummary({super.key, required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GrantEligibility? eligibility = opportunity.eligibility;
    final String? amount = opportunity.fundingAmount;
    if (eligibility == null && amount == null) return const SizedBox.shrink();

    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final String? note = opportunity.eligibilityNote;
    final String? matchFunding = opportunity.matchFunding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (eligibility != null)
              Builder(
                builder: (context) {
                  final (Color color, IconData icon) = eligibilityStyle(
                    eligibility,
                  );
                  return Chip(
                    avatar: Icon(icon, size: 16, color: color),
                    label: Text(strings.grantEligibilityLabel(eligibility)),
                    side: BorderSide(color: color.withValues(alpha: 0.6)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
            if (amount != null)
              Chip(
                avatar: const Icon(Icons.payments_outlined, size: 16),
                label: Text(amount),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        if (note != null || matchFunding != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              ?note,
              if (matchFunding != null &&
                  !(note ?? '').toLowerCase().contains('match'))
                strings.matchFundingLabel(matchFunding),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
