import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart'
    show RiskLevel, RiskLevelX;
import 'package:jva_projecttracker/models/proposal_approval.dart';

/// The proposal *document's* own authoring completeness — a different
/// question from [OpportunityPipelineStage] (which tracks the
/// opportunity's overall bid lifecycle) or `ClassificationStatus`.
/// `finalized` is the terminal state, reached only via the Submission
/// Workspace's "Submit Proposal" action once the Validation Engine confirms
/// the proposal is submittable (Milestone 4.4) — this app has no "unsubmit"
/// flow, a deliberate scope decision, not an oversight. See ADR-008.
enum ProposalStatus { draft, readyForReview, finalized }

extension ProposalStatusX on ProposalStatus {
  String get label => switch (this) {
    ProposalStatus.draft => 'Draft',
    ProposalStatus.readyForReview => 'Ready for Review',
    ProposalStatus.finalized => 'Submitted',
  };

  static ProposalStatus fromString(String value) {
    return ProposalStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProposalStatus.draft,
    );
  }
}

/// The AI Submission Review's own overall verdict (Milestone 4.4) — distinct
/// from the deterministic [ValidationCheckId]-based readiness the Validation
/// Engine computes; this one is Gemini's judgment call, so it's a separate,
/// AI-only enum rather than being forced into a shared "readiness" type.
enum SubmissionReviewReadiness { ready, needsWork, notReady }

extension SubmissionReviewReadinessX on SubmissionReviewReadiness {
  String get label => switch (this) {
    SubmissionReviewReadiness.ready => 'Ready',
    SubmissionReviewReadiness.needsWork => 'Needs Work',
    SubmissionReviewReadiness.notReady => 'Not Ready',
  };

  static SubmissionReviewReadiness fromString(String value) {
    return SubmissionReviewReadiness.values.firstWhere(
      (r) => r.name == value,
      orElse: () => SubmissionReviewReadiness.needsWork,
    );
  }
}

/// The proposal document for one [Opportunity] — one per opportunity by
/// convention (not a hard database constraint; see ADR-008). Its content
/// lives in [ProposalSection] (its own collection, keyed by [id] as
/// `proposalId`) rather than an embedded list, per this project's "never
/// embed entire objects" rule.
class Proposal {
  final String id;
  final String opportunityId;
  final String title;
  final ProposalStatus status;

  /// The proposal's owner — a plain free-text name/email, mirroring
  /// `Opportunity.assignedTo` exactly (no user-directory picker exists in
  /// this app). Milestone 4.1 (AI Proposal Workspace) addition.
  final String? assignedTo;

  /// When [status] last transitioned to [ProposalStatus.readyForReview] —
  /// `null` if it never has, or after being reopened to draft. Set by
  /// `ProposalService.updateStatus`, not directly. Milestone 4.1 (AI
  /// Proposal Workspace) addition — powers the workspace's Timeline section.
  final DateTime? readyForReviewAt;

  /// Internal sign-off decisions (Milestone 4.4) — only decided roles are
  /// stored; use `mergedApprovals` to see all 5 roles. Persisted via
  /// `ProposalService.updateApprovals`, never edited directly.
  final List<ProposalApproval> approvals;

  // --- AI Submission Review (Milestone 4.4) --- same shape as
  // Opportunity's strategic-review fields: narrative List<String> bullets,
  // each already a self-contained "why," no separate reason field.
  final DateTime? submissionReviewedAt;
  final SubmissionReviewReadiness? submissionReviewReadiness;
  final RiskLevel? submissionReviewRiskLevel;
  final List<String> submissionReviewMissingEvidence;
  final List<String> submissionReviewWeakSections;
  final List<String> submissionReviewStrongSections;
  final List<String> submissionReviewComplianceConcerns;
  final List<String> submissionReviewRecommendedImprovements;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Proposal({
    required this.id,
    required this.opportunityId,
    required this.title,
    this.status = ProposalStatus.draft,
    this.assignedTo,
    this.readyForReviewAt,
    this.approvals = const [],
    this.submissionReviewedAt,
    this.submissionReviewReadiness,
    this.submissionReviewRiskLevel,
    this.submissionReviewMissingEvidence = const [],
    this.submissionReviewWeakSections = const [],
    this.submissionReviewStrongSections = const [],
    this.submissionReviewComplianceConcerns = const [],
    this.submissionReviewRecommendedImprovements = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Proposal.fromMap(String id, Map<String, dynamic> map) {
    return Proposal(
      id: id,
      opportunityId: map['opportunityId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      status: ProposalStatusX.fromString(map['status'] as String? ?? 'draft'),
      assignedTo: map['assignedTo'] as String?,
      readyForReviewAt: (map['readyForReviewAt'] as Timestamp?)?.toDate(),
      approvals: (map['approvals'] as List? ?? const [])
          .map(
            (a) =>
                ProposalApproval.fromMap(Map<String, dynamic>.from(a as Map)),
          )
          .toList(),
      submissionReviewedAt: (map['submissionReviewedAt'] as Timestamp?)
          ?.toDate(),
      submissionReviewReadiness: map['submissionReviewReadiness'] != null
          ? SubmissionReviewReadinessX.fromString(
              map['submissionReviewReadiness'] as String,
            )
          : null,
      submissionReviewRiskLevel: map['submissionReviewRiskLevel'] != null
          ? RiskLevelX.fromString(map['submissionReviewRiskLevel'] as String)
          : null,
      submissionReviewMissingEvidence: List<String>.from(
        map['submissionReviewMissingEvidence'] as List? ?? const [],
      ),
      submissionReviewWeakSections: List<String>.from(
        map['submissionReviewWeakSections'] as List? ?? const [],
      ),
      submissionReviewStrongSections: List<String>.from(
        map['submissionReviewStrongSections'] as List? ?? const [],
      ),
      submissionReviewComplianceConcerns: List<String>.from(
        map['submissionReviewComplianceConcerns'] as List? ?? const [],
      ),
      submissionReviewRecommendedImprovements: List<String>.from(
        map['submissionReviewRecommendedImprovements'] as List? ?? const [],
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opportunityId': opportunityId,
      'title': title,
      'status': status.name,
      'assignedTo': assignedTo,
      'readyForReviewAt': readyForReviewAt != null
          ? Timestamp.fromDate(readyForReviewAt!)
          : null,
      'approvals': approvals.map((a) => a.toMap()).toList(),
      'submissionReviewedAt': submissionReviewedAt != null
          ? Timestamp.fromDate(submissionReviewedAt!)
          : null,
      'submissionReviewReadiness': submissionReviewReadiness?.name,
      'submissionReviewRiskLevel': submissionReviewRiskLevel?.name,
      'submissionReviewMissingEvidence': submissionReviewMissingEvidence,
      'submissionReviewWeakSections': submissionReviewWeakSections,
      'submissionReviewStrongSections': submissionReviewStrongSections,
      'submissionReviewComplianceConcerns': submissionReviewComplianceConcerns,
      'submissionReviewRecommendedImprovements':
          submissionReviewRecommendedImprovements,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
