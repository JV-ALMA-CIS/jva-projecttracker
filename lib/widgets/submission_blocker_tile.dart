import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/executive_summary.dart';
import 'package:jva_projecttracker/services/submission_blockers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

Color _severityColor(ExecutiveInsightSeverity s) => switch (s) {
  ExecutiveInsightSeverity.info => Colors.blue,
  ExecutiveInsightSeverity.watch => Colors.orange,
  ExecutiveInsightSeverity.risk => Colors.red,
};

IconData _categoryIcon(SubmissionBlockerCategory c) => switch (c) {
  SubmissionBlockerCategory.proposalSection => Icons.description_outlined,
  SubmissionBlockerCategory.document => Icons.folder_outlined,
  SubmissionBlockerCategory.recommendation => Icons.psychology_outlined,
  SubmissionBlockerCategory.submissionRecord => Icons.assignment_outlined,
};

/// One row in the Submission Workspace's consolidated Blockers panel —
/// color-coded by [SubmissionBlocker.severity] so risk items stand out from
/// items that are merely worth watching.
class SubmissionBlockerTile extends StatelessWidget {
  const SubmissionBlockerTile({super.key, required this.blocker});

  final SubmissionBlocker blocker;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(blocker.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
            child: Icon(
              _categoryIcon(blocker.category),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(blocker.title)),
        ],
      ),
    );
  }
}
