import 'package:cloud_firestore/cloud_firestore.dart';

/// The fixed set of internal sign-offs a proposal needs before it can be
/// submitted. See the Submission Workspace (Milestone 4.4) — this is a
/// small, bounded (5-role) set with no independent lifecycle of its own, so
/// it's embedded on [Proposal] rather than given its own collection (unlike
/// `ProposalSection`, which is open-ended and individually regenerated).
enum ApprovalRole {
  technicalLead,
  finance,
  legal,
  businessDevelopment,
  executiveManagement,
}

extension ApprovalRoleX on ApprovalRole {
  String get label => switch (this) {
    ApprovalRole.technicalLead => 'Technical Lead',
    ApprovalRole.finance => 'Finance',
    ApprovalRole.legal => 'Legal',
    ApprovalRole.businessDevelopment => 'Business Development',
    ApprovalRole.executiveManagement => 'Executive Management',
  };

  static ApprovalRole fromString(String value) {
    return ApprovalRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ApprovalRole.technicalLead,
    );
  }
}

enum ApprovalDecision { pending, approved, rejected }

extension ApprovalDecisionX on ApprovalDecision {
  String get label => switch (this) {
    ApprovalDecision.pending => 'Pending',
    ApprovalDecision.approved => 'Approved',
    ApprovalDecision.rejected => 'Rejected',
  };

  static ApprovalDecision fromString(String value) {
    return ApprovalDecision.values.firstWhere(
      (d) => d.name == value,
      orElse: () => ApprovalDecision.pending,
    );
  }
}

/// One role's sign-off decision on a proposal. Embedded as a list on
/// [Proposal.approvals] — storage only ever holds roles that have actually
/// been decided; use [mergedApprovals] to get all 5 roles for display.
class ProposalApproval {
  const ProposalApproval({
    required this.role,
    this.decision = ApprovalDecision.pending,
    this.approverName,
    this.comment,
    this.decidedAt,
  });

  final ApprovalRole role;
  final ApprovalDecision decision;
  final String? approverName;
  final String? comment;
  final DateTime? decidedAt;

  factory ProposalApproval.fromMap(Map<String, dynamic> map) {
    return ProposalApproval(
      role: ApprovalRoleX.fromString(map['role'] as String? ?? ''),
      decision: ApprovalDecisionX.fromString(
        map['decision'] as String? ?? 'pending',
      ),
      approverName: map['approverName'] as String?,
      comment: map['comment'] as String?,
      decidedAt: (map['decidedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'decision': decision.name,
      'approverName': approverName,
      'comment': comment,
      'decidedAt': decidedAt != null ? Timestamp.fromDate(decidedAt!) : null,
    };
  }
}

/// Returns all 5 [ApprovalRole]s, defaulting any role missing from [stored]
/// to a plain [ApprovalDecision.pending] entry — so the UI and the
/// Validation Engine always see a complete 5-role picture even though
/// Firestore only stores roles that have actually been decided.
List<ProposalApproval> mergedApprovals(List<ProposalApproval> stored) {
  final byRole = {for (final a in stored) a.role: a};
  return [
    for (final role in ApprovalRole.values)
      byRole[role] ?? ProposalApproval(role: role),
  ];
}

/// Pure upsert: returns a new list with [role]'s entry replaced (or added)
/// by a freshly-decided [ProposalApproval]. Only decided roles are kept —
/// callers persist the result directly via `ProposalService.updateApprovals`.
List<ProposalApproval> applyApprovalDecision(
  List<ProposalApproval> current, {
  required ApprovalRole role,
  required ApprovalDecision decision,
  String? approverName,
  String? comment,
  required DateTime now,
}) {
  final updated = ProposalApproval(
    role: role,
    decision: decision,
    approverName: approverName,
    comment: comment,
    decidedAt: now,
  );
  return [
    for (final a in current)
      if (a.role != role) a,
    updated,
  ];
}
