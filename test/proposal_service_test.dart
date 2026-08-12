import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProposalService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ProposalService(firestore: firestore);
  });

  Proposal buildProposal({
    required String opportunityId,
    required DateTime now,
  }) {
    return Proposal(
      id: '',
      opportunityId: opportunityId,
      title: 'Proposal for opportunity $opportunityId',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('watchByOpportunityId returns null when no proposal exists', () async {
    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal, isNull);
  });

  test(
    'create writes a proposal that watchByOpportunityId then returns',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      await service.create(
        buildProposal(opportunityId: 'opportunity-1', now: now),
      );

      final proposal = await service
          .watchByOpportunityId('opportunity-1')
          .first;
      expect(proposal, isNotNull);
      expect(proposal!.opportunityId, 'opportunity-1');
      expect(proposal.status, ProposalStatus.draft);
    },
  );

  test(
    'watchByOpportunityId only returns the matching opportunity\'s proposal',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      await service.create(
        buildProposal(opportunityId: 'opportunity-1', now: now),
      );
      await service.create(
        buildProposal(opportunityId: 'opportunity-2', now: now),
      );

      final proposal = await service
          .watchByOpportunityId('opportunity-2')
          .first;
      expect(proposal!.opportunityId, 'opportunity-2');
    },
  );

  test('updateTitle updates the title', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildProposal(opportunityId: 'opportunity-1', now: now),
    );

    await service.updateTitle(id, 'A Better Title');

    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal!.title, 'A Better Title');
  });

  test('updateStatus updates the status', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildProposal(opportunityId: 'opportunity-1', now: now),
    );

    await service.updateStatus(id, ProposalStatus.readyForReview);

    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal!.status, ProposalStatus.readyForReview);
  });

  test(
    'updateStatus stamps readyForReviewAt when marking ready for review, and clears it on reopen',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      final id = await service.create(
        buildProposal(opportunityId: 'opportunity-1', now: now),
      );

      await service.updateStatus(id, ProposalStatus.readyForReview);
      var proposal = await service.watchByOpportunityId('opportunity-1').first;
      expect(proposal!.status, ProposalStatus.readyForReview);
      expect(proposal.readyForReviewAt, isNotNull);

      await service.updateStatus(id, ProposalStatus.draft);
      proposal = await service.watchByOpportunityId('opportunity-1').first;
      expect(proposal!.status, ProposalStatus.draft);
      expect(proposal.readyForReviewAt, isNull);
    },
  );

  test('updateAssignedTo sets the proposal owner', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildProposal(opportunityId: 'opportunity-1', now: now),
    );

    await service.updateAssignedTo(id, 'jane@example.com');

    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal!.assignedTo, 'jane@example.com');
  });

  test(
    'updateStatus to finalized leaves an existing readyForReviewAt untouched',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      final id = await service.create(
        buildProposal(opportunityId: 'opportunity-1', now: now),
      );

      await service.updateStatus(id, ProposalStatus.readyForReview);
      var proposal = await service.watchByOpportunityId('opportunity-1').first;
      final readyAt = proposal!.readyForReviewAt;
      expect(readyAt, isNotNull);

      await service.updateStatus(id, ProposalStatus.finalized);
      proposal = await service.watchByOpportunityId('opportunity-1').first;
      expect(proposal!.status, ProposalStatus.finalized);
      expect(proposal.readyForReviewAt?.toUtc(), readyAt!.toUtc());
    },
  );

  test('updateApprovals persists the given approval list', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildProposal(opportunityId: 'opportunity-1', now: now),
    );

    await service.updateApprovals(id, [
      ProposalApproval(
        role: ApprovalRole.legal,
        decision: ApprovalDecision.approved,
        approverName: 'Jane Legal',
        decidedAt: now,
      ),
    ]);

    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal!.approvals, hasLength(1));
    expect(proposal.approvals.single.role, ApprovalRole.legal);
    expect(proposal.approvals.single.decision, ApprovalDecision.approved);
    expect(proposal.approvals.single.approverName, 'Jane Legal');
  });

  test('delete removes the proposal', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildProposal(opportunityId: 'opportunity-1', now: now),
    );

    await service.delete(id);

    final proposal = await service.watchByOpportunityId('opportunity-1').first;
    expect(proposal, isNull);
  });
}
