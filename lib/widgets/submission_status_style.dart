import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A consistent accent color per [SubmissionStatus] — shared between the
/// Opportunity Workspace's Submission entry-point tile and the Submission
/// Workspace's own header, following the same "one style helper, several
/// screens" convention already established by `priority_style.dart`. Reads
/// [AppStatusColors] rather than raw `Colors.*` so this stays in sync with
/// the rest of the app's status-color system.
Color submissionStatusColor(SubmissionStatus status) => switch (status) {
  SubmissionStatus.preparing => AppStatusColors.neutral,
  SubmissionStatus.submitted => AppStatusColors.info,
  SubmissionStatus.underEvaluation => AppStatusColors.ai,
  SubmissionStatus.clarificationRequested => AppStatusColors.warning,
  SubmissionStatus.awarded => AppStatusColors.success,
  SubmissionStatus.lost => AppStatusColors.danger,
  SubmissionStatus.withdrawn => AppStatusColors.neutral,
};
