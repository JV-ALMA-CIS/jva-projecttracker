import 'package:flutter/material.dart';
import 'package:jva_projecttracker/services/submission_validation.dart';

/// Maps [ValidationSeverity] to a (background, foreground) Material 3
/// container color pair — same shape/pattern as `proposalReadinessColors`/
/// `knowledgeHealthColors`. Rendered only as a plain `Chip`, never a new
/// gauge widget, consistent with ADR-004.
(Color background, Color foreground) validationSeverityColors(
  ColorScheme scheme,
  ValidationSeverity severity,
) {
  return switch (severity) {
    ValidationSeverity.passed => (
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    ),
    ValidationSeverity.warning => (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    ValidationSeverity.blocker => (
      scheme.errorContainer,
      scheme.onErrorContainer,
    ),
  };
}
