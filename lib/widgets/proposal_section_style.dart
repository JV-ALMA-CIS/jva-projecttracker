import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';

/// Maps [ProposalSectionType] to a leading icon for `ProposalSectionCard`.
IconData proposalSectionTypeIcon(ProposalSectionType type) {
  return switch (type) {
    ProposalSectionType.executiveSummary => Icons.summarize_outlined,
    ProposalSectionType.understandingOfRequirements =>
      Icons.fact_check_outlined,
    ProposalSectionType.companyProfile => Icons.apartment_outlined,
    ProposalSectionType.technicalApproach => Icons.architecture_outlined,
    ProposalSectionType.methodology => Icons.schema_outlined,
    ProposalSectionType.workPlan => Icons.event_note_outlined,
    ProposalSectionType.companyExperience => Icons.history_edu_outlined,
    ProposalSectionType.teamQualifications => Icons.groups_outlined,
    ProposalSectionType.productsAndTechnologies => Icons.memory_outlined,
    ProposalSectionType.riskManagement => Icons.warning_amber_outlined,
    ProposalSectionType.pricingApproach => Icons.payments_outlined,
    ProposalSectionType.sustainability => Icons.eco_outlined,
    ProposalSectionType.innovation => Icons.lightbulb_outline,
    ProposalSectionType.valueProposition => Icons.stars_outlined,
    ProposalSectionType.conclusion => Icons.flag_outlined,
    ProposalSectionType.custom => Icons.article_outlined,
  };
}

/// Maps [ProposalSectionStatus] to a (background, foreground, icon) triple
/// for its status chip — same "plain `Chip`, never a new gauge/badge
/// widget" philosophy as `priorityColors` (ADR-004/005), applied to a
/// different enum. `approved` reuses `primaryContainer` (this app's seed
/// color) as its "done" signal, matching the Material 3 default rather
/// than inventing a bespoke green.
(Color background, Color foreground, IconData icon) proposalSectionStatusStyle(
  ColorScheme scheme,
  ProposalSectionStatus status,
) {
  return switch (status) {
    ProposalSectionStatus.notStarted => (
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
      Icons.radio_button_unchecked,
    ),
    ProposalSectionStatus.aiDrafted => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      Icons.auto_awesome,
    ),
    ProposalSectionStatus.edited => (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      Icons.edit_note,
    ),
    ProposalSectionStatus.approved => (
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      Icons.check_circle,
    ),
  };
}
