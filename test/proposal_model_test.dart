import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';

void main() {
  test('Proposal round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 8, 1);
    final updatedAt = DateTime.utc(2024, 8, 2);

    final proposal = Proposal(
      id: 'proposal-1',
      opportunityId: 'opportunity-1',
      title: 'Proposal for Rural Water Tender',
      status: ProposalStatus.readyForReview,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = proposal.toMap();
    final restored = Proposal.fromMap(proposal.id, map);

    expect(restored.opportunityId, proposal.opportunityId);
    expect(restored.title, proposal.title);
    expect(restored.status, ProposalStatus.readyForReview);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('Proposal defaults status to draft on a partial document', () {
    final now = DateTime.utc(2024, 8, 1);
    final restored = Proposal.fromMap('proposal-2', {
      'opportunityId': 'opportunity-2',
      'title': 'Proposal for Legacy Opportunity',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.status, ProposalStatus.draft);
  });

  test('Proposal round-trips assignedTo and readyForReviewAt', () {
    final now = DateTime.utc(2024, 8, 1);
    final readyAt = DateTime.utc(2024, 8, 5);

    final proposal = Proposal(
      id: 'proposal-3',
      opportunityId: 'opportunity-3',
      title: 'Proposal for Road Tender',
      status: ProposalStatus.readyForReview,
      assignedTo: 'jane@example.com',
      readyForReviewAt: readyAt,
      createdAt: now,
      updatedAt: now,
    );

    final restored = Proposal.fromMap(proposal.id, proposal.toMap());

    expect(restored.assignedTo, 'jane@example.com');
    expect(restored.readyForReviewAt?.toUtc(), readyAt.toUtc());
  });

  test(
    'Proposal defaults assignedTo/readyForReviewAt to null when missing',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = Proposal.fromMap('proposal-4', {
        'opportunityId': 'opportunity-4',
        'title': 'Legacy proposal',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.assignedTo, isNull);
      expect(restored.readyForReviewAt, isNull);
    },
  );

  test('Proposal round-trips the finalized status', () {
    final now = DateTime.utc(2024, 8, 1);
    final proposal = Proposal(
      id: 'proposal-5',
      opportunityId: 'opportunity-5',
      title: 'Proposal for Bridge Tender',
      status: ProposalStatus.finalized,
      createdAt: now,
      updatedAt: now,
    );

    final restored = Proposal.fromMap(proposal.id, proposal.toMap());

    expect(restored.status, ProposalStatus.finalized);
  });

  test('Proposal round-trips approvals', () {
    final now = DateTime.utc(2024, 8, 1);
    final proposal = Proposal(
      id: 'proposal-6',
      opportunityId: 'opportunity-6',
      title: 'Proposal for Water Tender',
      approvals: [
        ProposalApproval(
          role: ApprovalRole.legal,
          decision: ApprovalDecision.approved,
          approverName: 'Jane Legal',
          comment: 'Looks good',
          decidedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final restored = Proposal.fromMap(proposal.id, proposal.toMap());

    expect(restored.approvals, hasLength(1));
    expect(restored.approvals.single.role, ApprovalRole.legal);
    expect(restored.approvals.single.decision, ApprovalDecision.approved);
    expect(restored.approvals.single.approverName, 'Jane Legal');
    expect(restored.approvals.single.comment, 'Looks good');
    expect(restored.approvals.single.decidedAt?.toUtc(), now.toUtc());
  });

  test('Proposal round-trips AI submission review fields', () {
    final now = DateTime.utc(2024, 8, 1);
    final proposal = Proposal(
      id: 'proposal-7',
      opportunityId: 'opportunity-7',
      title: 'Proposal for School Tender',
      submissionReviewedAt: now,
      submissionReviewReadiness: SubmissionReviewReadiness.ready,
      submissionReviewRiskLevel: RiskLevel.low,
      submissionReviewMissingEvidence: const ['Missing ISO certificate'],
      submissionReviewWeakSections: const ['Methodology: too generic'],
      submissionReviewStrongSections: const ['Team: highly qualified'],
      submissionReviewComplianceConcerns: const [
        'No local registration on file',
      ],
      submissionReviewRecommendedImprovements: const [
        'Add a risk mitigation table',
      ],
      createdAt: now,
      updatedAt: now,
    );

    final restored = Proposal.fromMap(proposal.id, proposal.toMap());

    expect(restored.submissionReviewedAt?.toUtc(), now.toUtc());
    expect(restored.submissionReviewReadiness, SubmissionReviewReadiness.ready);
    expect(restored.submissionReviewRiskLevel, RiskLevel.low);
    expect(restored.submissionReviewMissingEvidence, [
      'Missing ISO certificate',
    ]);
    expect(restored.submissionReviewWeakSections, ['Methodology: too generic']);
    expect(restored.submissionReviewStrongSections, ['Team: highly qualified']);
    expect(restored.submissionReviewComplianceConcerns, [
      'No local registration on file',
    ]);
    expect(restored.submissionReviewRecommendedImprovements, [
      'Add a risk mitigation table',
    ]);
  });

  test(
    'Proposal defaults approvals and AI submission review fields to empty/null when missing',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = Proposal.fromMap('proposal-8', {
        'opportunityId': 'opportunity-8',
        'title': 'Legacy proposal',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.approvals, isEmpty);
      expect(restored.submissionReviewedAt, isNull);
      expect(restored.submissionReviewReadiness, isNull);
      expect(restored.submissionReviewRiskLevel, isNull);
      expect(restored.submissionReviewMissingEvidence, isEmpty);
    },
  );
}
