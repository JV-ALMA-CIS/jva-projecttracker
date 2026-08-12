import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';

void main() {
  final now = DateTime.utc(2024, 8, 1);

  test('toMap/fromMap round-trips every field', () {
    final approval = ProposalApproval(
      role: ApprovalRole.finance,
      decision: ApprovalDecision.approved,
      approverName: 'Jane Finance',
      comment: 'Budget checks out',
      decidedAt: now,
    );

    final restored = ProposalApproval.fromMap(approval.toMap());

    expect(restored.role, ApprovalRole.finance);
    expect(restored.decision, ApprovalDecision.approved);
    expect(restored.approverName, 'Jane Finance');
    expect(restored.comment, 'Budget checks out');
    expect(restored.decidedAt?.toUtc(), now.toUtc());
  });

  test('fromMap defaults decision to pending and optional fields to null', () {
    final restored = ProposalApproval.fromMap({'role': 'legal'});

    expect(restored.role, ApprovalRole.legal);
    expect(restored.decision, ApprovalDecision.pending);
    expect(restored.approverName, isNull);
    expect(restored.comment, isNull);
    expect(restored.decidedAt, isNull);
  });

  test(
    'mergedApprovals fills in all 5 roles, defaulting missing ones to pending',
    () {
      final merged = mergedApprovals([
        ProposalApproval(
          role: ApprovalRole.legal,
          decision: ApprovalDecision.approved,
        ),
      ]);

      expect(merged, hasLength(5));
      expect(merged.map((a) => a.role).toSet(), ApprovalRole.values.toSet());
      final legal = merged.firstWhere((a) => a.role == ApprovalRole.legal);
      expect(legal.decision, ApprovalDecision.approved);
      final others = merged.where((a) => a.role != ApprovalRole.legal);
      expect(
        others.every((a) => a.decision == ApprovalDecision.pending),
        isTrue,
      );
    },
  );

  test('applyApprovalDecision adds a new role that was not present before', () {
    final updated = applyApprovalDecision(
      const [],
      role: ApprovalRole.technicalLead,
      decision: ApprovalDecision.approved,
      approverName: 'John Tech',
      now: now,
    );

    expect(updated, hasLength(1));
    expect(updated.single.role, ApprovalRole.technicalLead);
    expect(updated.single.decision, ApprovalDecision.approved);
    expect(updated.single.approverName, 'John Tech');
    expect(updated.single.decidedAt, now);
  });

  test(
    'applyApprovalDecision replaces an existing role rather than duplicating it',
    () {
      final current = [
        ProposalApproval(
          role: ApprovalRole.finance,
          decision: ApprovalDecision.pending,
        ),
      ];

      final updated = applyApprovalDecision(
        current,
        role: ApprovalRole.finance,
        decision: ApprovalDecision.rejected,
        comment: 'Numbers do not add up',
        now: now,
      );

      expect(updated, hasLength(1));
      expect(updated.single.decision, ApprovalDecision.rejected);
      expect(updated.single.comment, 'Numbers do not add up');
    },
  );

  test(
    'ApprovalRoleX.fromString falls back to technicalLead for unknown values',
    () {
      expect(
        ApprovalRoleX.fromString('not-a-real-role'),
        ApprovalRole.technicalLead,
      );
    },
  );

  test(
    'ApprovalDecisionX.fromString falls back to pending for unknown values',
    () {
      expect(
        ApprovalDecisionX.fromString('not-a-real-decision'),
        ApprovalDecision.pending,
      );
    },
  );
}
