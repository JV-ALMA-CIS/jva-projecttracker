import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';
import 'package:jva_projecttracker/services/submission_validation.dart';

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

  ProposalSection section({
    ProposalSectionType type = ProposalSectionType.executiveSummary,
    ProposalSectionStatus status = ProposalSectionStatus.approved,
  }) {
    return ProposalSection(
      id: 'section-${type.name}',
      proposalId: 'proposal-1',
      order: 0,
      type: type,
      title: type.label,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  Proposal proposal({
    String? assignedTo,
    List<ProposalApproval> approvals = const [],
  }) {
    return Proposal(
      id: 'proposal-1',
      opportunityId: 'opp-1',
      title: 'Test proposal',
      assignedTo: assignedTo,
      approvals: approvals,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<ProposalApproval> allApproved() => [
    for (final role in ApprovalRole.values)
      ProposalApproval(role: role, decision: ApprovalDecision.approved),
  ];

  test('is fully submittable when every check passes', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(
        assignedTo: 'jane@example.com',
        approvals: allApproved(),
      ),
      sections: [section()],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    expect(validation.isSubmittable, isTrue);
    expect(validation.blockers, isEmpty);
    expect(validation.readinessScore, 1.0);
  });

  test('sectionsComplete blocks when a section is not approved', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(
        assignedTo: 'jane@example.com',
        approvals: allApproved(),
      ),
      sections: [section(status: ProposalSectionStatus.edited)],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    expect(validation.isSubmittable, isFalse);
    expect(
      validation.blockers.map((c) => c.id),
      contains(ValidationCheckId.sectionsComplete),
    );
  });

  test('sectionsComplete blocks when there are no sections at all', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(
        assignedTo: 'jane@example.com',
        approvals: allApproved(),
      ),
      sections: const [],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    expect(
      validation.blockers.map((c) => c.id),
      contains(ValidationCheckId.sectionsComplete),
    );
  });

  test('documentsAttached blocks when document readiness is not ready', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(
        assignedTo: 'jane@example.com',
        approvals: allApproved(),
      ),
      sections: [section()],
      documentReadiness: readiness(isReady: false),
      now: now,
    );

    expect(
      validation.blockers.map((c) => c.id),
      contains(ValidationCheckId.documentsAttached),
    );
  });

  test('requiredSignatures blocks when not every role has approved', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(assignedTo: 'jane@example.com', approvals: const []),
      sections: [section()],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    expect(
      validation.blockers.map((c) => c.id),
      contains(ValidationCheckId.requiredSignatures),
    );
  });

  test('metadataComplete warns (not blocks) when no owner is assigned', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(assignedTo: null, approvals: allApproved()),
      sections: [section()],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    final metadataCheck = validation.checks.firstWhere(
      (c) => c.id == ValidationCheckId.metadataComplete,
    );
    expect(metadataCheck.severity, ValidationSeverity.warning);
    // A warning is not a blocker, so the proposal can still be submittable.
    expect(validation.isSubmittable, isTrue);
  });

  test(
    'budgetComplete passes (not applicable) when no pricing section exists',
    () {
      final validation = deriveSubmissionValidation(
        proposal: proposal(
          assignedTo: 'jane@example.com',
          approvals: allApproved(),
        ),
        sections: [section()],
        documentReadiness: readiness(isReady: true),
        now: now,
      );

      final budgetCheck = validation.checks.firstWhere(
        (c) => c.id == ValidationCheckId.budgetComplete,
      );
      expect(budgetCheck.severity, ValidationSeverity.passed);
    },
  );

  test('budgetComplete blocks when a pricing section exists but is empty', () {
    final validation = deriveSubmissionValidation(
      proposal: proposal(
        assignedTo: 'jane@example.com',
        approvals: allApproved(),
      ),
      sections: [
        section(),
        section(
          type: ProposalSectionType.pricingApproach,
          status: ProposalSectionStatus.notStarted,
        ),
      ],
      documentReadiness: readiness(isReady: true),
      now: now,
    );

    expect(
      validation.blockers.map((c) => c.id),
      contains(ValidationCheckId.budgetComplete),
    );
  });

  test(
    'budgetComplete passes when a pricing section exists and has content',
    () {
      final validation = deriveSubmissionValidation(
        proposal: proposal(
          assignedTo: 'jane@example.com',
          approvals: allApproved(),
        ),
        sections: [
          section(),
          section(
            type: ProposalSectionType.pricingApproach,
            status: ProposalSectionStatus.approved,
          ),
        ],
        documentReadiness: readiness(isReady: true),
        now: now,
      );

      final budgetCheck = validation.checks.firstWhere(
        (c) => c.id == ValidationCheckId.budgetComplete,
      );
      expect(budgetCheck.severity, ValidationSeverity.passed);
    },
  );
}
