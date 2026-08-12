import 'package:flutter/material.dart';
import 'package:jva_projecttracker/services/proposal_readiness.dart';

/// Maps [ProposalReadiness] to a (background, foreground) Material 3
/// container color pair — same shape/pattern as `priorityColors`/
/// `riskColors`/`knowledgeHealthColors`. Rendered only as a plain `Chip`,
/// never a new gauge/percentage widget, consistent with ADR-004.
(Color background, Color foreground) proposalReadinessColors(
  ColorScheme scheme,
  ProposalReadiness readiness,
) {
  return switch (readiness) {
    ProposalReadiness.readyToSubmit => (
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    ),
    ProposalReadiness.onTrack => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
    ),
    ProposalReadiness.atRisk => (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    ProposalReadiness.behindSchedule => (
      scheme.errorContainer,
      scheme.onErrorContainer,
    ),
  };
}
