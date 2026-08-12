import 'package:jva_projecttracker/models/proposal.dart';

/// A proposal's at-a-glance submission readiness — categorical, never a
/// numeric gauge (the completion percentage already has one, on
/// `ProposalProgressRing`; this is a distinct signal blending completion
/// with the deadline). See ADR-004's "no new percentage visual language"
/// precedent, applied here.
enum ProposalReadiness { readyToSubmit, onTrack, atRisk, behindSchedule }

const _kAtRiskWindowDays = 7;
const _kAtRiskProgressThreshold = 0.7;

/// Derives [ProposalReadiness] from data already available on the Proposal
/// Workspace — no new Firestore reads. [sectionProgress] is the same
/// 0.0-1.0 value `proposalSectionProgressProvider` already computes;
/// [deadline] is `Opportunity.deadline`, already loaded by the workspace.
ProposalReadiness deriveProposalReadiness({
  required double sectionProgress,
  required ProposalStatus status,
  required DateTime? deadline,
  required DateTime now,
}) {
  if (status == ProposalStatus.readyForReview && sectionProgress >= 1.0) {
    return ProposalReadiness.readyToSubmit;
  }

  if (deadline != null) {
    final daysLeft = deadline.difference(now).inDays;
    if (daysLeft < 0) return ProposalReadiness.behindSchedule;
    if (daysLeft <= _kAtRiskWindowDays &&
        sectionProgress < _kAtRiskProgressThreshold) {
      return ProposalReadiness.atRisk;
    }
  }

  return ProposalReadiness.onTrack;
}
