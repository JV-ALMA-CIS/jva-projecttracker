import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

/// The Submission Workspace's timeline steps (Milestone 4.4). The first 6
/// are proposal-side milestones, derived from data already tracked; the
/// last 3 are simply the existing [OpportunityPipelineStage] values this
/// app has tracked since ADR-002 — no parallel status chain is invented.
enum SubmissionMilestone {
  proposalCreated,
  aiGenerated,
  documentsReady,
  internalReview,
  managementApproval,
  submissionReady,
  submitted,
  evaluation,
  awardedOrLost,
}

class SubmissionTimelineEntry {
  const SubmissionTimelineEntry({
    required this.milestone,
    required this.isComplete,
    required this.isCurrent,
  });

  final SubmissionMilestone milestone;
  final bool isComplete;
  final bool isCurrent;
}

/// Derives the full 9-step timeline purely from data already loaded — no
/// new Firestore reads. Exactly one entry is marked `isCurrent`: the first
/// one not yet complete (or the last one, once everything is).
List<SubmissionTimelineEntry> deriveSubmissionTimeline({
  required Proposal proposal,
  required List<ProposalSection> sections,
  required SubmissionReadiness documentReadiness,
  required OpportunityPipelineStage pipelineStage,
}) {
  final aiGenerated = sections.any((s) => s.aiGeneratedAt != null);
  final internalReviewStarted = mergedApprovals(
    proposal.approvals,
  ).any((a) => a.decision != ApprovalDecision.pending);
  final managementApproved = mergedApprovals(proposal.approvals).any(
    (a) =>
        a.role == ApprovalRole.executiveManagement &&
        a.decision == ApprovalDecision.approved,
  );
  final submissionReady =
      proposal.status == ProposalStatus.readyForReview ||
      proposal.status == ProposalStatus.finalized;
  final submitted =
      proposal.status == ProposalStatus.finalized ||
      pipelineStage.index >= OpportunityPipelineStage.submitted.index;
  final inEvaluation =
      pipelineStage.index >= OpportunityPipelineStage.evaluation.index;
  // `lost` sits between `awarded` and `projectStarted`/`completed` in the
  // enum's linear order, so a plain index comparison already covers every
  // stage that means "the award decision has been made," win or lose.
  final decided = pipelineStage.index >= OpportunityPipelineStage.awarded.index;

  final completion = <SubmissionMilestone, bool>{
    SubmissionMilestone.proposalCreated: true,
    SubmissionMilestone.aiGenerated: aiGenerated,
    SubmissionMilestone.documentsReady: documentReadiness.isReady,
    SubmissionMilestone.internalReview: internalReviewStarted,
    SubmissionMilestone.managementApproval: managementApproved,
    SubmissionMilestone.submissionReady: submissionReady,
    SubmissionMilestone.submitted: submitted,
    SubmissionMilestone.evaluation: inEvaluation,
    SubmissionMilestone.awardedOrLost: decided,
  };

  final order = SubmissionMilestone.values;
  final firstIncompleteIndex = order.indexWhere((m) => !completion[m]!);
  final currentIndex = firstIncompleteIndex == -1
      ? order.length - 1
      : firstIncompleteIndex;

  return [
    for (final (index, milestone) in order.indexed)
      SubmissionTimelineEntry(
        milestone: milestone,
        isComplete: completion[milestone]!,
        isCurrent: index == currentIndex,
      ),
  ];
}
