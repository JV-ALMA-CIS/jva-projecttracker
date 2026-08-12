import 'package:cloud_firestore/cloud_firestore.dart';

/// The proposal section kinds this app knows about. `custom` is for
/// anything a user adds by hand. Milestone 4.2 (AI Proposal Generation
/// Engine) uses each type's [label] as the section-focus signal in its
/// Gemini prompt — no per-type template needed.
enum ProposalSectionType {
  executiveSummary,
  understandingOfRequirements,
  companyProfile,
  technicalApproach,
  methodology,
  workPlan,
  companyExperience,
  teamQualifications,
  productsAndTechnologies,
  riskManagement,
  pricingApproach,
  sustainability,
  innovation,
  valueProposition,
  conclusion,
  custom,
}

extension ProposalSectionTypeX on ProposalSectionType {
  String get label => switch (this) {
    ProposalSectionType.executiveSummary => 'Executive Summary',
    ProposalSectionType.understandingOfRequirements =>
      'Understanding of Requirements',
    ProposalSectionType.companyProfile => 'Company Profile',
    ProposalSectionType.technicalApproach => 'Technical Approach',
    ProposalSectionType.methodology => 'Methodology',
    ProposalSectionType.workPlan => 'Work Plan',
    ProposalSectionType.companyExperience => 'Relevant Experience',
    ProposalSectionType.teamQualifications => 'Team & Expertise',
    ProposalSectionType.productsAndTechnologies => 'Products & Technologies',
    ProposalSectionType.riskManagement => 'Risk Management',
    ProposalSectionType.pricingApproach => 'Pricing Approach',
    ProposalSectionType.sustainability => 'Sustainability',
    ProposalSectionType.innovation => 'Innovation',
    ProposalSectionType.valueProposition => 'Value Proposition',
    ProposalSectionType.conclusion => 'Conclusion',
    ProposalSectionType.custom => 'Custom Section',
  };

  static ProposalSectionType fromString(String value) {
    return ProposalSectionType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ProposalSectionType.custom,
    );
  }

  /// The 13 section types a new proposal is scaffolded with, in the order
  /// Milestone 4.2 defined them — everything except `custom` and the two
  /// pre-4.2 types (`understandingOfRequirements`, `pricingApproach`) that
  /// remain valid, addable types but are no longer part of the default
  /// scaffold.
  static const List<ProposalSectionType> standardSet = [
    ProposalSectionType.executiveSummary,
    ProposalSectionType.companyProfile,
    ProposalSectionType.technicalApproach,
    ProposalSectionType.methodology,
    ProposalSectionType.workPlan,
    ProposalSectionType.teamQualifications,
    ProposalSectionType.companyExperience,
    ProposalSectionType.productsAndTechnologies,
    ProposalSectionType.riskManagement,
    ProposalSectionType.sustainability,
    ProposalSectionType.innovation,
    ProposalSectionType.valueProposition,
    ProposalSectionType.conclusion,
  ];
}

/// Progress on a single section, independent of the parent [Proposal]'s own
/// [ProposalStatus]. `aiDrafted` — AI-authored, not yet touched by a human —
/// is set only by the `generateProposalSection` Cloud Function (Milestone
/// 4.2); a human edit (`ProposalSectionService.updateContent`) always moves
/// a section to `edited` regardless of its prior status, which is what
/// makes `edited` double as the "manually edited" signal with no separate
/// boolean field.
enum ProposalSectionStatus { notStarted, aiDrafted, edited, approved }

extension ProposalSectionStatusX on ProposalSectionStatus {
  String get label => switch (this) {
    ProposalSectionStatus.notStarted => 'Not Started',
    ProposalSectionStatus.aiDrafted => 'AI Drafted',
    ProposalSectionStatus.edited => 'Edited',
    ProposalSectionStatus.approved => 'Approved',
  };

  static ProposalSectionStatus fromString(String value) {
    return ProposalSectionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProposalSectionStatus.notStarted,
    );
  }
}

/// One section of a [Proposal] — its own collection (`proposalSections`),
/// keyed by [proposalId], rather than an array embedded on [Proposal]. This
/// lets Milestone 4.2's AI generator regenerate a single section with one
/// document write instead of rewriting the whole proposal, and lets
/// sections carry independent status/ordering. See ADR-008.
///
/// The `aiSource*Ids` fields below are this section's AI-generation
/// provenance — which Company Intelligence entities Gemini drew on to
/// write it — in the exact same 8-field-per-category shape every other AI
/// pass in this app already uses (classification/match-analysis/strategic-
/// review/recommendations), rendered the same way via
/// `RecommendedEntityChips<T>`. `previousContent`/`previousStatus` are a
/// single-slot undo buffer (not a full version history) snapshotted by the
/// Cloud Function immediately before it overwrites non-empty content.
class ProposalSection {
  final String id;
  final String proposalId;
  final int order;
  final ProposalSectionType type;
  final String title;
  final String content;
  final ProposalSectionStatus status;

  /// This section's owner — a plain free-text name/email, same convention
  /// as `Proposal.assignedTo`/`Opportunity.assignedTo`. Milestone 4.1 (AI
  /// Proposal Workspace) addition.
  final String? assignedTo;

  // --- AI Proposal Generation Engine (Milestone 4.2) ---
  final DateTime? aiGeneratedAt;
  final int? aiConfidence;
  final List<String> aiSourceBusinessUnitIds;
  final List<String> aiSourceProductIds;
  final List<String> aiSourceServiceIds;
  final List<String> aiSourceCapabilityIds;
  final List<String> aiSourceTechnologyIds;
  final List<String> aiSourceIndustryIds;
  final List<String> aiSourceExperienceIds;
  final List<String> aiSourceKnowledgeArticleIds;
  final String? previousContent;
  final ProposalSectionStatus? previousStatus;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProposalSection({
    required this.id,
    required this.proposalId,
    required this.order,
    required this.type,
    required this.title,
    this.content = '',
    this.status = ProposalSectionStatus.notStarted,
    this.assignedTo,
    this.aiGeneratedAt,
    this.aiConfidence,
    this.aiSourceBusinessUnitIds = const [],
    this.aiSourceProductIds = const [],
    this.aiSourceServiceIds = const [],
    this.aiSourceCapabilityIds = const [],
    this.aiSourceTechnologyIds = const [],
    this.aiSourceIndustryIds = const [],
    this.aiSourceExperienceIds = const [],
    this.aiSourceKnowledgeArticleIds = const [],
    this.previousContent,
    this.previousStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProposalSection.fromMap(String id, Map<String, dynamic> map) {
    return ProposalSection(
      id: id,
      proposalId: map['proposalId'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      type: ProposalSectionTypeX.fromString(map['type'] as String? ?? 'custom'),
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      status: ProposalSectionStatusX.fromString(
        map['status'] as String? ?? 'notStarted',
      ),
      assignedTo: map['assignedTo'] as String?,
      aiGeneratedAt: (map['aiGeneratedAt'] as Timestamp?)?.toDate(),
      aiConfidence: (map['aiConfidence'] as num?)?.toInt(),
      aiSourceBusinessUnitIds: List<String>.from(
        map['aiSourceBusinessUnitIds'] as List? ?? const [],
      ),
      aiSourceProductIds: List<String>.from(
        map['aiSourceProductIds'] as List? ?? const [],
      ),
      aiSourceServiceIds: List<String>.from(
        map['aiSourceServiceIds'] as List? ?? const [],
      ),
      aiSourceCapabilityIds: List<String>.from(
        map['aiSourceCapabilityIds'] as List? ?? const [],
      ),
      aiSourceTechnologyIds: List<String>.from(
        map['aiSourceTechnologyIds'] as List? ?? const [],
      ),
      aiSourceIndustryIds: List<String>.from(
        map['aiSourceIndustryIds'] as List? ?? const [],
      ),
      aiSourceExperienceIds: List<String>.from(
        map['aiSourceExperienceIds'] as List? ?? const [],
      ),
      aiSourceKnowledgeArticleIds: List<String>.from(
        map['aiSourceKnowledgeArticleIds'] as List? ?? const [],
      ),
      previousContent: map['previousContent'] as String?,
      previousStatus: map['previousStatus'] != null
          ? ProposalSectionStatusX.fromString(map['previousStatus'] as String)
          : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proposalId': proposalId,
      'order': order,
      'type': type.name,
      'title': title,
      'content': content,
      'status': status.name,
      'assignedTo': assignedTo,
      'aiGeneratedAt': aiGeneratedAt != null
          ? Timestamp.fromDate(aiGeneratedAt!)
          : null,
      'aiConfidence': aiConfidence,
      'aiSourceBusinessUnitIds': aiSourceBusinessUnitIds,
      'aiSourceProductIds': aiSourceProductIds,
      'aiSourceServiceIds': aiSourceServiceIds,
      'aiSourceCapabilityIds': aiSourceCapabilityIds,
      'aiSourceTechnologyIds': aiSourceTechnologyIds,
      'aiSourceIndustryIds': aiSourceIndustryIds,
      'aiSourceExperienceIds': aiSourceExperienceIds,
      'aiSourceKnowledgeArticleIds': aiSourceKnowledgeArticleIds,
      'previousContent': previousContent,
      'previousStatus': previousStatus?.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
