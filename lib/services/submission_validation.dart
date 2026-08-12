import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

/// The concrete, derivable checks behind "is this proposal ready to
/// submit" — see the Submission Workspace (Milestone 4.4) Decision 4/5 for
/// how the brief's 8 example checks collapse onto these 5 real ones:
/// "required documents attached"/"expired documents"/"missing
/// certifications"/"mandatory attachments" all resolve to [documentsAttached]
/// (this app has exactly one document model — Milestone 4.3's
/// [SubmissionReadiness]); "required signatures" resolves to
/// [requiredSignatures] (no e-signature model exists — a role's approval
/// *is* its signature here).
enum ValidationCheckId {
  sectionsComplete,
  documentsAttached,
  requiredSignatures,
  metadataComplete,
  budgetComplete,
}

enum ValidationSeverity { passed, warning, blocker }

class ValidationCheck {
  const ValidationCheck({required this.id, required this.severity});

  final ValidationCheckId id;
  final ValidationSeverity severity;
}

/// A proposal's overall submission validation — see [deriveSubmissionValidation].
class SubmissionValidation {
  const SubmissionValidation({
    required this.checks,
    required this.readinessScore,
    required this.blockers,
    required this.isSubmittable,
  });

  final List<ValidationCheck> checks;

  /// Fraction (0.0-1.0) of checks that passed — rendered as a `Chip`/ring,
  /// never a new gauge widget, consistent with ADR-004.
  final double readinessScore;
  final List<ValidationCheck> blockers;
  final bool isSubmittable;
}

/// Derives [SubmissionValidation] purely from data already loaded elsewhere
/// — no new Firestore reads, no AI call. [documentReadiness] is Milestone
/// 4.3's [deriveSubmissionReadiness] output for this proposal.
SubmissionValidation deriveSubmissionValidation({
  required Proposal proposal,
  required List<ProposalSection> sections,
  required SubmissionReadiness documentReadiness,
  required DateTime now,
}) {
  final checks = <ValidationCheck>[
    ValidationCheck(
      id: ValidationCheckId.sectionsComplete,
      severity:
          sections.isNotEmpty &&
              sections.every((s) => s.status == ProposalSectionStatus.approved)
          ? ValidationSeverity.passed
          : ValidationSeverity.blocker,
    ),
    ValidationCheck(
      id: ValidationCheckId.documentsAttached,
      severity: documentReadiness.isReady
          ? ValidationSeverity.passed
          : ValidationSeverity.blocker,
    ),
    ValidationCheck(
      id: ValidationCheckId.requiredSignatures,
      severity:
          mergedApprovals(
            proposal.approvals,
          ).every((a) => a.decision == ApprovalDecision.approved)
          ? ValidationSeverity.passed
          : ValidationSeverity.blocker,
    ),
    ValidationCheck(
      id: ValidationCheckId.metadataComplete,
      severity: (proposal.assignedTo ?? '').trim().isNotEmpty
          ? ValidationSeverity.passed
          : ValidationSeverity.warning,
    ),
    ValidationCheck(
      id: ValidationCheckId.budgetComplete,
      severity: _budgetSeverity(sections),
    ),
  ];

  final blockers = checks
      .where((c) => c.severity == ValidationSeverity.blocker)
      .toList();
  final passedCount = checks
      .where((c) => c.severity == ValidationSeverity.passed)
      .length;

  return SubmissionValidation(
    checks: checks,
    readinessScore: checks.isEmpty ? 0 : passedCount / checks.length,
    blockers: blockers,
    isSubmittable: blockers.isEmpty,
  );
}

/// No pricing section on this proposal at all → not applicable, treated as
/// `passed` rather than a fabricated hard requirement (see Decision 5 — this
/// app has no budget/financial model, and `pricingApproach` isn't part of
/// the default 13-section scaffold). A pricing section that exists but is
/// still empty is a real, honest blocker.
ValidationSeverity _budgetSeverity(List<ProposalSection> sections) {
  final pricingSections = sections.where(
    (s) => s.type == ProposalSectionType.pricingApproach,
  );
  if (pricingSections.isEmpty) return ValidationSeverity.passed;
  final hasContent = pricingSections.any(
    (s) => s.status != ProposalSectionStatus.notStarted,
  );
  return hasContent ? ValidationSeverity.passed : ValidationSeverity.blocker;
}
