import 'package:cloud_firestore/cloud_firestore.dart';

/// How the bid was (or will be) physically submitted.
enum SubmissionMethod { portal, email, physical, other }

extension SubmissionMethodX on SubmissionMethod {
  String get label => switch (this) {
    SubmissionMethod.portal => 'Portal',
    SubmissionMethod.email => 'Email',
    SubmissionMethod.physical => 'Physical',
    SubmissionMethod.other => 'Other',
  };

  static SubmissionMethod fromString(String value) {
    return SubmissionMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => SubmissionMethod.portal,
    );
  }
}

/// The bid-submission lifecycle — distinct from both [ProposalStatus]
/// (authoring completeness) and [OpportunityPipelineStage] (the broader
/// bid lifecycle the whole opportunity moves through). This is narrowly
/// about the submission *event* itself: has it gone out, and what happened
/// after.
enum SubmissionStatus {
  preparing,
  submitted,
  underEvaluation,
  clarificationRequested,
  awarded,
  lost,
  withdrawn,
}

extension SubmissionStatusX on SubmissionStatus {
  String get label => switch (this) {
    SubmissionStatus.preparing => 'Preparing',
    SubmissionStatus.submitted => 'Submitted',
    SubmissionStatus.underEvaluation => 'Under Evaluation',
    SubmissionStatus.clarificationRequested => 'Clarification Requested',
    SubmissionStatus.awarded => 'Awarded',
    SubmissionStatus.lost => 'Lost',
    SubmissionStatus.withdrawn => 'Withdrawn',
  };

  bool get isClosed =>
      this == SubmissionStatus.awarded ||
      this == SubmissionStatus.lost ||
      this == SubmissionStatus.withdrawn;

  static SubmissionStatus fromString(String value) {
    return SubmissionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SubmissionStatus.preparing,
    );
  }
}

/// The formal record of one opportunity's bid submission (Milestone 4.5 —
/// Submission Workspace). One per opportunity by convention, same as
/// [Proposal] — created once a proposal is ready to go out the door, not
/// at opportunity-discovery time. Deliberately narrow: it does not
/// duplicate `Opportunity.submittedDate`/`decisionDate`/`closedReason`
/// (which remain the pipeline-level record of those dates) — instead it
/// adds the operational detail those flat fields don't carry (submission
/// method, reference/confirmation number, evaluation window, outcome
/// notes, its own owner). Not to be confused with the unrelated
/// `CompanyApplication` entity (the company's own software product
/// catalog, Phase 1) — this is a new, separately-named collection
/// (`submissions`) precisely to avoid that collision. See ADR-010.
class Submission {
  final String id;
  final String opportunityId;
  final String proposalId;
  final SubmissionStatus status;
  final SubmissionMethod method;
  final String? referenceNumber;
  final String? assignedTo;
  final DateTime? submittedAt;
  final DateTime? evaluationDate;
  final DateTime? outcomeAt;
  final String? outcomeNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Submission({
    required this.id,
    required this.opportunityId,
    required this.proposalId,
    this.status = SubmissionStatus.preparing,
    this.method = SubmissionMethod.portal,
    this.referenceNumber,
    this.assignedTo,
    this.submittedAt,
    this.evaluationDate,
    this.outcomeAt,
    this.outcomeNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Submission.fromMap(String id, Map<String, dynamic> map) {
    return Submission(
      id: id,
      opportunityId: map['opportunityId'] as String? ?? '',
      proposalId: map['proposalId'] as String? ?? '',
      status: SubmissionStatusX.fromString(
        map['status'] as String? ?? 'preparing',
      ),
      method: SubmissionMethodX.fromString(
        map['method'] as String? ?? 'portal',
      ),
      referenceNumber: map['referenceNumber'] as String?,
      assignedTo: map['assignedTo'] as String?,
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      evaluationDate: (map['evaluationDate'] as Timestamp?)?.toDate(),
      outcomeAt: (map['outcomeAt'] as Timestamp?)?.toDate(),
      outcomeNotes: map['outcomeNotes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opportunityId': opportunityId,
      'proposalId': proposalId,
      'status': status.name,
      'method': method.name,
      'referenceNumber': referenceNumber,
      'assignedTo': assignedTo,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : null,
      'evaluationDate': evaluationDate != null
          ? Timestamp.fromDate(evaluationDate!)
          : null,
      'outcomeAt': outcomeAt != null ? Timestamp.fromDate(outcomeAt!) : null,
      'outcomeNotes': outcomeNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
