import 'package:flutter/material.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';

/// Maps [KnowledgeHealth] to a (background, foreground) Material 3 container
/// color pair — same shape/pattern as `priorityColors`/`riskColors` in
/// `priority_style.dart`. Rendered only as a plain `Chip`, never a new
/// gauge/percentage widget, consistent with ADR-004's "no new percentage
/// visual language" decision.
(Color background, Color foreground) knowledgeHealthColors(
  ColorScheme scheme,
  KnowledgeHealth health,
) {
  return switch (health) {
    KnowledgeHealth.covered => (
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    ),
    KnowledgeHealth.attention => (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    KnowledgeHealth.gap => (scheme.errorContainer, scheme.onErrorContainer),
    KnowledgeHealth.noData => (
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    ),
  };
}
