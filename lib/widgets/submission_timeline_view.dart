import 'package:flutter/material.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/submission_timeline.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A modern, connected-dot vertical timeline for the Submission Workspace's
/// 9-step flow — the brief's "modern visual timeline instead of a list."
/// Complete steps are filled/primary, the current step is outlined/bold,
/// upcoming steps are muted. No external package — a plain `Column` of
/// dot+line+label rows, same complexity class as `ProposalProgressTracker`.
class SubmissionTimelineView extends StatelessWidget {
  const SubmissionTimelineView({
    super.key,
    required this.entries,
    required this.strings,
  });

  final List<SubmissionTimelineEntry> entries;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, entry) in entries.indexed)
          _TimelineRow(
            entry: entry,
            label: strings.submissionMilestoneLabel(entry.milestone),
            isLast: index == entries.length - 1,
            theme: theme,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.label,
    required this.isLast,
    required this.theme,
  });

  final SubmissionTimelineEntry entry;
  final String label;
  final bool isLast;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final Color dotColor = entry.isComplete
        ? scheme.primary
        : entry.isCurrent
        ? scheme.primary
        : scheme.outlineVariant;
    final Color lineColor = entry.isComplete
        ? scheme.primary
        : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.isComplete ? dotColor : Colors.transparent,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                label,
                style: entry.isCurrent
                    ? theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: entry.isComplete
                            ? null
                            : scheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
