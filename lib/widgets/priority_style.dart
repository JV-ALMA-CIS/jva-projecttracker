import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// Maps [OpportunityPriority] to a (background, foreground) Material 3
/// container color pair — shared by `RecommendationCard` and
/// `NotificationTile` so both render priority identically. Still a plain
/// `Chip`/`Icon` tint, never a new gauge/badge widget, consistent with
/// ADR-004/005's "no new percentage visual language" decision.
(Color background, Color foreground) priorityColors(
  ColorScheme scheme,
  OpportunityPriority priority,
) {
  return switch (priority) {
    OpportunityPriority.high => (
      scheme.errorContainer,
      scheme.onErrorContainer,
    ),
    OpportunityPriority.medium => (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    OpportunityPriority.low => (
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    ),
  };
}

/// Maps [RiskLevel] to a (background, foreground) Material 3 container color
/// pair — the risk-side counterpart of [priorityColors], same shape and
/// same "no new percentage/gauge visual language" rule.
(Color background, Color foreground) riskColors(
  ColorScheme scheme,
  RiskLevel risk,
) {
  return switch (risk) {
    RiskLevel.high => (scheme.errorContainer, scheme.onErrorContainer),
    RiskLevel.medium => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    RiskLevel.low => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
  };
}
