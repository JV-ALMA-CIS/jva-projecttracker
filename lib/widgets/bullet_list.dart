import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A labeled bulleted list — e.g. strengths/risks/next-actions. Factors out
/// a pattern that already exists as a private `_bulletList` method in both
/// `OpportunityWorkspaceScreen` and `ProposalWorkspaceScreen`; this is the
/// version new screens (starting with the Submission Workspace) should use.
/// Consolidating those two pre-existing copies onto this widget is a
/// worthwhile follow-up cleanup, not done here to keep this milestone's
/// diff isolated to the Submission Workspace, per this project's "don't
/// redesign unrelated modules" rule.
class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
