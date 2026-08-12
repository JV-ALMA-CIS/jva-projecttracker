import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/submission.dart';

/// A consistent accent color per [SubmissionStatus] — shared between the
/// Opportunity Workspace's Submission entry-point tile and the Submission
/// Workspace's own header, following the same "one style helper, several
/// screens" convention already established by `priority_style.dart`.
Color submissionStatusColor(SubmissionStatus status) => switch (status) {
  SubmissionStatus.preparing => Colors.blueGrey,
  SubmissionStatus.submitted => Colors.blue,
  SubmissionStatus.underEvaluation => Colors.indigo,
  SubmissionStatus.clarificationRequested => Colors.orange,
  SubmissionStatus.awarded => Colors.green,
  SubmissionStatus.lost => Colors.red,
  SubmissionStatus.withdrawn => Colors.grey,
};
