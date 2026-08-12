import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';
import 'package:jva_projecttracker/services/submission_timeline.dart';

void main() {
  final now = DateTime.utc(2024, 8, 1);

  SubmissionReadiness readiness({required bool isReady}) {
    return SubmissionReadiness(
      isReady: isReady,
      requiredCategories: const {},
      uploadedCategories: const {},
      missingCategories: const {},
      expiredDocuments: const [],
      pendingReviewDocuments: const [],
      needsUpdateDocuments: const [],
    );
  }

  Proposal proposal({
    ProposalStatus status = ProposalStatus.draft,
    List<ProposalApproval> approvals = const [],
  }) {
    return Proposal(
      id: 'proposal-1',
      opportunityId: 'opp-1',
      title: 'Test proposal',
      status: status,
      approvals: approvals,
      createdAt: now,
      updatedAt: now,
    );
  }

  ProposalSection section({DateTime? aiGeneratedAt}) {
    return ProposalSection(
      id: 'section-1',
      proposalId: 'proposal-1',
      order: 0,
      type: ProposalSectionType.executiveSummary,
      title: 'Executive Summary',
      aiGeneratedAt: aiGeneratedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  SubmissionTimelineEntry entryFor(
    List<SubmissionTimelineEntry> entries,
    SubmissionMilestone milestone,
  ) {
    return entries.firstWhere((e) => e.milestone == milestone);
  }

  test('a freshly-created proposal has only proposalCreated complete', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(
      entryFor(entries, SubmissionMilestone.proposalCreated).isComplete,
      isTrue,
    );
    expect(
      entryFor(entries, SubmissionMilestone.aiGenerated).isComplete,
      isFalse,
    );
    expect(
      entryFor(entries, SubmissionMilestone.aiGenerated).isCurrent,
      isTrue,
    );
  });

  test('aiGenerated completes once any section has aiGeneratedAt set', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(),
      sections: [section(aiGeneratedAt: now)],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(
      entryFor(entries, SubmissionMilestone.aiGenerated).isComplete,
      isTrue,
    );
  });

  test('documentsReady completes once document readiness is ready', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(),
      sections: [section()],
      documentReadiness: readiness(isReady: true),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(
      entryFor(entries, SubmissionMilestone.documentsReady).isComplete,
      isTrue,
    );
  });

  test('internalReview completes once any approval decision is recorded', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(
        approvals: [
          ProposalApproval(
            role: ApprovalRole.legal,
            decision: ApprovalDecision.approved,
          ),
        ],
      ),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(
      entryFor(entries, SubmissionMilestone.internalReview).isComplete,
      isTrue,
    );
    expect(
      entryFor(entries, SubmissionMilestone.managementApproval).isComplete,
      isFalse,
    );
  });

  test(
    'managementApproval completes only once Executive Management approves',
    () {
      final entries = deriveSubmissionTimeline(
        proposal: proposal(
          approvals: [
            ProposalApproval(
              role: ApprovalRole.executiveManagement,
              decision: ApprovalDecision.approved,
            ),
          ],
        ),
        sections: [section()],
        documentReadiness: readiness(isReady: false),
        pipelineStage: OpportunityPipelineStage.proposalStarted,
      );

      expect(
        entryFor(entries, SubmissionMilestone.managementApproval).isComplete,
        isTrue,
      );
    },
  );

  test('submissionReady completes once the proposal is readyForReview', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(status: ProposalStatus.readyForReview),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(
      entryFor(entries, SubmissionMilestone.submissionReady).isComplete,
      isTrue,
    );
  });

  test('submitted completes once the proposal is finalized', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(status: ProposalStatus.finalized),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(entryFor(entries, SubmissionMilestone.submitted).isComplete, isTrue);
  });

  test(
    'submitted/evaluation/awardedOrLost track the opportunity pipeline stage',
    () {
      final entries = deriveSubmissionTimeline(
        proposal: proposal(status: ProposalStatus.finalized),
        sections: [section()],
        documentReadiness: readiness(isReady: true),
        pipelineStage: OpportunityPipelineStage.awarded,
      );

      expect(
        entryFor(entries, SubmissionMilestone.submitted).isComplete,
        isTrue,
      );
      expect(
        entryFor(entries, SubmissionMilestone.evaluation).isComplete,
        isTrue,
      );
      expect(
        entryFor(entries, SubmissionMilestone.awardedOrLost).isComplete,
        isTrue,
      );
    },
  );

  test('lost also counts as a decided awardedOrLost milestone', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(status: ProposalStatus.finalized),
      sections: [section()],
      documentReadiness: readiness(isReady: true),
      pipelineStage: OpportunityPipelineStage.lost,
    );

    expect(
      entryFor(entries, SubmissionMilestone.awardedOrLost).isComplete,
      isTrue,
    );
  });

  test('exactly one entry is marked current', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      pipelineStage: OpportunityPipelineStage.proposalStarted,
    );

    expect(entries.where((e) => e.isCurrent), hasLength(1));
  });

  test('when everything is complete, the last milestone is current', () {
    final entries = deriveSubmissionTimeline(
      proposal: proposal(
        status: ProposalStatus.finalized,
        approvals: [
          ProposalApproval(
            role: ApprovalRole.executiveManagement,
            decision: ApprovalDecision.approved,
          ),
        ],
      ),
      sections: [section(aiGeneratedAt: now)],
      documentReadiness: readiness(isReady: true),
      pipelineStage: OpportunityPipelineStage.awarded,
    );

    expect(entries.last.isCurrent, isTrue);
  });
}
