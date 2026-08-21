import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// The platform's one section-title pattern (page-body sections like
/// "Needs Your Attention," "Opportunity Intelligence," "Delivery & Wins" —
/// one step below [PageHeader]'s page title). [accentColor], when given,
/// renders a small colored dot before the title so a functional section
/// reads as visually distinct from its neighbors (e.g. amber for attention,
/// purple for AI, teal for operations — see [AppStatusColors]) — this
/// folds in a pattern several screens (`dashboard_screen.dart` chief among
/// them) previously hand-rolled locally as their own private
/// `_sectionDot()` helper, so every section header gets it for free instead
/// of being re-implemented per screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accentColor,
  });

  final String title;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (accentColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
