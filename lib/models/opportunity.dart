import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

/// One tender-stated eligibility requirement — entered by hand on the
/// Opportunity Workspace (Phase 1 of company certifications). Deliberately
/// manual rather than AI-parsed from tender documents: full-document OCR
/// for mandatory certification lists is a real future feature, not
/// something this app should guess at from thin classification text today
/// (see the Certifications brief's explicit "do not block on AI" rule).
/// [gradeOrClass] is optional — a requirement can be "must hold an active
/// ISO certification" with no specific grade, or "NCA class 7 or higher."
class OpportunityCertificationRequirement {
  const OpportunityCertificationRequirement({
    required this.type,
    this.gradeOrClass,
    required this.label,
  });

  final CertificationType type;
  final String? gradeOrClass;

  /// Human-readable summary shown on the Eligibility section and in gap
  /// messages, e.g. "NCA Class 7" — kept as a plain string (rather than
  /// always derived from [type]/[gradeOrClass]) so a tender's exact wording
  /// can be preserved verbatim.
  final String label;

  factory OpportunityCertificationRequirement.fromMap(
    Map<String, dynamic> map,
  ) {
    return OpportunityCertificationRequirement(
      type: CertificationTypeX.fromString(map['type'] as String? ?? 'other'),
      gradeOrClass: map['gradeOrClass'] as String?,
      label: map['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type.name, 'gradeOrClass': gradeOrClass, 'label': label};
  }
}

enum OpportunityStatus {
  discovered,
  reviewing,
  applied,
  won,
  lost,
  dismissed,
  archived,
}

extension OpportunityStatusX on OpportunityStatus {
  String get label => switch (this) {
    OpportunityStatus.discovered => 'Discovered',
    OpportunityStatus.reviewing => 'Reviewing',
    OpportunityStatus.applied => 'Applied',
    OpportunityStatus.won => 'Won',
    OpportunityStatus.lost => 'Lost',
    OpportunityStatus.dismissed => 'Dismissed',
    OpportunityStatus.archived => 'Archived',
  };

  static OpportunityStatus fromString(String value) {
    return OpportunityStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OpportunityStatus.discovered,
    );
  }
}

/// Where an opportunity sits in the (not-yet-built) AI classification
/// pipeline. `notClassified` is the default for every opportunity today —
/// nothing sets `processing`/`classified`/`needsReview` yet, since that's
/// future AI work; the enum exists now so the pipeline has somewhere to
/// write its state without a later schema change.
enum ClassificationStatus { notClassified, processing, classified, needsReview }

extension ClassificationStatusX on ClassificationStatus {
  String get label => switch (this) {
    ClassificationStatus.notClassified => 'Not Classified',
    ClassificationStatus.processing => 'Processing',
    ClassificationStatus.classified => 'Classified',
    ClassificationStatus.needsReview => 'Needs Review',
  };

  static ClassificationStatus fromString(String value) {
    return ClassificationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ClassificationStatus.notClassified,
    );
  }
}

/// The detailed internal workflow stage of an opportunity — distinct from
/// (and more granular than) [OpportunityStatus], which stays as the simple
/// discovered/reviewing/applied/won/lost/dismissed field the existing
/// Cloud Function and list-screen dropdown already use. See ADR-002 in
/// `docs/architecture/` for why both fields exist rather than merging them.
enum OpportunityPipelineStage {
  discovered,
  classified,
  reviewed,
  qualified,
  approved,
  proposalStarted,
  proposalReady,
  submitted,
  evaluation,
  negotiation,
  awarded,
  lost,
  projectStarted,
  completed,
}

extension OpportunityPipelineStageX on OpportunityPipelineStage {
  String get label => switch (this) {
    OpportunityPipelineStage.discovered => 'Discovered',
    OpportunityPipelineStage.classified => 'Classified',
    OpportunityPipelineStage.reviewed => 'Reviewed',
    OpportunityPipelineStage.qualified => 'Qualified',
    OpportunityPipelineStage.approved => 'Approved',
    OpportunityPipelineStage.proposalStarted => 'Proposal Started',
    OpportunityPipelineStage.proposalReady => 'Proposal Ready',
    OpportunityPipelineStage.submitted => 'Submitted',
    OpportunityPipelineStage.evaluation => 'Evaluation',
    OpportunityPipelineStage.negotiation => 'Negotiation',
    OpportunityPipelineStage.awarded => 'Awarded',
    OpportunityPipelineStage.lost => 'Lost',
    OpportunityPipelineStage.projectStarted => 'Project Started',
    OpportunityPipelineStage.completed => 'Completed',
  };

  static OpportunityPipelineStage fromString(String value) {
    return OpportunityPipelineStage.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OpportunityPipelineStage.discovered,
    );
  }
}

enum EstimatedComplexity { low, medium, high }

extension EstimatedComplexityX on EstimatedComplexity {
  String get label => switch (this) {
    EstimatedComplexity.low => 'Low',
    EstimatedComplexity.medium => 'Medium',
    EstimatedComplexity.high => 'High',
  };

  static EstimatedComplexity fromString(String value) {
    return EstimatedComplexity.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EstimatedComplexity.medium,
    );
  }
}

enum RiskLevel { low, medium, high }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
    RiskLevel.low => 'Low',
    RiskLevel.medium => 'Medium',
    RiskLevel.high => 'High',
  };

  static RiskLevel fromString(String value) {
    return RiskLevel.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RiskLevel.medium,
    );
  }
}

enum OpportunityPriority { low, medium, high }

extension OpportunityPriorityX on OpportunityPriority {
  String get label => switch (this) {
    OpportunityPriority.low => 'Low',
    OpportunityPriority.medium => 'Medium',
    OpportunityPriority.high => 'High',
  };

  static OpportunityPriority fromString(String value) {
    return OpportunityPriority.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OpportunityPriority.medium,
    );
  }
}

/// The executive recommendation produced by an AI Strategic Review pass —
/// see ADR-005. Nullable on [Opportunity] rather than defaulting to one of
/// these three, since "has a review run yet" is answered by
/// `strategicReviewedAt == null`, not by this enum (same "no redundant
/// status field" philosophy as match analysis — ADR-004 Decision 5).
enum StrategicReviewRecommendation { pursue, pursueWithCaution, doNotPursue }

extension StrategicReviewRecommendationX on StrategicReviewRecommendation {
  String get label => switch (this) {
    StrategicReviewRecommendation.pursue => 'Pursue',
    StrategicReviewRecommendation.pursueWithCaution => 'Pursue with Caution',
    StrategicReviewRecommendation.doNotPursue => 'Do Not Pursue',
  };

  static StrategicReviewRecommendation fromString(String value) {
    return StrategicReviewRecommendation.values.firstWhere(
      (s) => s.name == value,
      orElse: () => StrategicReviewRecommendation.pursueWithCaution,
    );
  }
}

/// Which external source category discovered an opportunity — see the
/// Opportunity Discovery Engine (Milestone 3.7). `manual` covers opportunities
/// entered by hand rather than through any automated source. Every value
/// except `manual` can be registered as a [DiscoverySource]; whether it has a
/// working automated adapter yet is a server-side concern
/// (`functions/index.js`'s `DISCOVERY_ADAPTERS` registry), not modeled here.
/// Deterministic geography-priority tier assigned at discovery time by
/// `classifyGeographyPriority` (functions/index.js) before an opportunity is
/// ever written — Kenya first, then East Africa, then the rest of Africa,
/// then everything else deemed strategically relevant enough to survive
/// `isRelevantCandidate`'s pre-filter. `unranked` covers legacy opportunities
/// written before this field existed, same "null/unranked rather than
/// guessed" convention as [DiscoverySourceType]/[BuyerTypeFacet].
enum GeographyPriority {
  kenya,
  eastAfrica,
  africa,
  internationalStrategic,
  unranked,
}

extension GeographyPriorityX on GeographyPriority {
  String get label => switch (this) {
    GeographyPriority.kenya => 'Kenya',
    GeographyPriority.eastAfrica => 'East Africa',
    GeographyPriority.africa => 'Africa',
    GeographyPriority.internationalStrategic => 'International',
    GeographyPriority.unranked => 'Unranked',
  };

  static GeographyPriority fromString(String value) {
    return GeographyPriority.values.firstWhere(
      (g) => g.name == value,
      orElse: () => GeographyPriority.unranked,
    );
  }
}

enum DiscoverySourceType {
  governmentProcurement,
  developmentOrganization,
  unProcurement,
  ngo,
  privateSector,
  rss,
  api,
  manual,
}

extension DiscoverySourceTypeX on DiscoverySourceType {
  String get label => switch (this) {
    DiscoverySourceType.governmentProcurement => 'Government Procurement',
    DiscoverySourceType.developmentOrganization => 'Development Organization',
    DiscoverySourceType.unProcurement => 'UN Procurement',
    DiscoverySourceType.ngo => 'NGO Opportunities',
    DiscoverySourceType.privateSector => 'Private Sector Tenders',
    DiscoverySourceType.rss => 'RSS Feed',
    DiscoverySourceType.api => 'API',
    DiscoverySourceType.manual => 'Manual Import',
  };

  static DiscoverySourceType fromString(String value) {
    return DiscoverySourceType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => DiscoverySourceType.manual,
    );
  }
}

/// An opportunity discovered via automated web search,
/// scored against the company's project & application history.
///
/// The classification/knowledge-graph fields below (`classificationStatus`
/// onward) are the central node connecting a discovered opportunity to the
/// rest of the Company Intelligence graph
/// (BusinessUnit/Product/Service/Capability/Technology/Industry/Experience/
/// KnowledgeArticle). They are all nullable (or default to an explicit
/// "not yet set" enum value) because nothing populates them automatically
/// yet — see ADR-001 in `docs/architecture/` — today they're edited by hand
/// from the Opportunities screen; a future AI classification pass is
/// expected to populate them after analyzing tender documents, without
/// requiring another schema change.
///
/// The pipeline fields below (`pipelineStage` onward, Milestone 3.2) track
/// the opportunity's internal workflow lifecycle. Every `pipelineStage`
/// transition is expected to go through [OpportunityService.transitionStage],
/// which also writes a corresponding `OpportunityEvent` — see ADR-002.
class Opportunity {
  final String id;
  final String title;
  final String description;
  final String sourceUrl;

  /// True once `sourceUrl` has been confirmed to actually load — either by
  /// the discovery-time HTTP check `createOpportunitiesFromCandidates`
  /// performs for every connector (functions/connectors/
  /// tenderSourceConnector.js) before writing, or by a human clicking "Mark
  /// as verified" on the Opportunity Workspace after checking it
  /// themselves. Exists because AI-search discovery
  /// (`ApiConnector._syncAiSearch`) can fabricate a plausible-looking but
  /// nonexistent tender URL — this flag is what lets the UI warn "this
  /// link hasn't been confirmed" instead of silently presenting a
  /// fabricated URL as equally trustworthy as a real one.
  ///
  /// Defaults to `false` — including for every opportunity written before
  /// this field existed. That's deliberate, not an oversight: a legacy
  /// document was never actually checked, so treating its absence as
  /// "verified" would hide exactly the fabricated-link problem this field
  /// exists to surface (an old AI-search opportunity with a dead link
  /// should show the same warning as a newly discovered one, not be
  /// silently exempted because it predates the check).
  final bool sourceUrlVerified;

  /// When [sourceUrlVerified] last became true — null if never verified
  /// (or predates this field, where [sourceUrlVerified] itself defaults to
  /// true without a timestamp). Purely informational (e.g. "verified 3
  /// months ago" could still be stale if the tender was later taken down),
  /// never used to gate anything.
  final DateTime? sourceUrlVerifiedAt;

  /// True when [sourceUrl] is not a tender-specific link at all but a
  /// fallback to the source's own `TenderSource.website` — written by
  /// `ApiConnector._syncAiSearch` (functions/connectors/apiConnector.js)
  /// when the grounding cross-check rejected the AI-suggested URL as
  /// unconfirmed/likely-fabricated, and the source has a known real
  /// website to point at instead of losing the opportunity entirely. Always
  /// paired with `sourceUrlVerified: false` (a fallback is never presented
  /// as confirmed) — this field exists only so the UI can show a distinct
  /// "fallback" badge rather than treating it identically to an ordinary
  /// unverified direct link. Defaults to `false`, including for every
  /// opportunity written before this field existed — same "absence means
  /// no, not unknown" convention as [sourceUrlVerified].
  final bool sourceUrlIsFallback;

  /// The match score (`overallMatchScore`, falling back to `fitScorePercent`
  /// — same precedence `buildNotifications` uses) at the moment a ≥70%
  /// match-score notification was last durably recorded for this
  /// opportunity — see [matchNotificationSentAt]. Null until the first time
  /// that happens. Distinct from the Notification Center's local read-state
  /// (`NotificationReadController`, device-only shared preferences): this
  /// field lives on the opportunity document itself, so "was this
  /// opportunity ever flagged as a strong match" survives a fresh install,
  /// a different device, or the Notification Center never having been
  /// opened — the local read-state alone is purely ephemeral.
  final int? lastNotifiedScore;

  /// When [lastNotifiedScore] was last written — null until the first
  /// ≥70% match-score notification is durably recorded. Purely
  /// informational, same convention as [sourceUrlVerifiedAt].
  final DateTime? matchNotificationSentAt;

  final String? client;
  final DateTime? deadline;
  final OpportunityStatus status;

  /// The procuring organization/client issuing the tender — e.g. "KTDA" —
  /// kept distinct from [client] (which historically doubles as a generic
  /// "who this opportunity is with" field across every discovery path) so a
  /// formally procured tender can record its issuing body precisely without
  /// changing [client]'s existing meaning for non-tender opportunities.
  /// Null for every opportunity written before this field existed, and for
  /// any opportunity where a procuring org doesn't apply.
  final String? procuringOrganization;

  /// The tender's own reference/publication number, entered verbatim as
  /// published by the procuring organization (e.g. "KTDA/ICT/2026/014") —
  /// free text since formats vary by issuer and this app must not assume
  /// any particular tender source's numbering scheme.
  final String? tenderReferenceNumber;

  /// Technologies/skills the tender explicitly requires (e.g. "Flutter",
  /// "Firebase", "Cloud Functions") — distinct from [technologyIds] (the
  /// Company Knowledge Graph's own catalog of technologies JV ALMA CIS has
  /// experience with, populated by the AI classification pass). This field
  /// is the tender's stated requirement as written, entered/edited by hand
  /// on the Opportunity Workspace; nothing here is auto-derived from
  /// [technologyIds] or vice versa.
  final List<String> requiredTechnologies;

  /// 0-100 estimated fit, produced by the Gemini scoring pipeline.
  final int fitScorePercent;
  final String fitReasoning;

  final List<String> tags;
  final DateTime discoveredAt;
  final DateTime updatedAt;

  // --- Opportunity Discovery Engine (Milestone 3.7) ---
  // Both null for every opportunity created before this milestone (including
  // ones written by the pre-existing ad-hoc searchOpportunities/
  // scheduledOpportunityDiscovery Cloud Functions, which still don't set
  // these) — provenance is "unknown/legacy" rather than defaulted to a real
  // source, since guessing one would be misleading.
  final String? discoverySourceId;
  final DiscoverySourceType? discoverySourceType;

  /// Set by `runOpportunityDiscovery`'s deterministic pre-filter for every
  /// opportunity discovered via AI search from this point forward — null for
  /// every opportunity written before this field existed (Tender Source
  /// connector opportunities included, since geography classification is
  /// currently only run in the AI-search discovery path).
  final GeographyPriority? geographyPriority;

  // --- Tender Source / Discovery Engine v2 (Milestone 3.8a) ---
  // Written by createOpportunitiesFromCandidates() in Cloud Functions for
  // every opportunity created via a TenderSource connector. Like the
  // discoverySource* pair above, all three are null for any opportunity
  // predating this milestone or created manually — provenance stays
  // "unknown/legacy" rather than guessed. TenderSource is the model going
  // forward per the 3.8a decision to deprecate (not delete/migrate)
  // DiscoverySource, so a given opportunity should have EITHER the
  // discoverySource* pair OR these three set, never both.
  final String? tenderSourceId;
  final TenderSourceCategory? tenderSourceCategory;
  final TenderDiscoveryMethod? tenderDiscoveryMethod;

  // --- Opportunity Intelligence foundation (Milestone 3.1) ---
  final ClassificationStatus classificationStatus;
  final String? classificationSummary;
  final List<String> industryIds;
  final List<String> technologyIds;
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> experienceIds;
  final List<String> knowledgeArticleIds;
  final String? opportunityType;
  final double? estimatedBudget;
  final String? estimatedDuration;
  final EstimatedComplexity? estimatedComplexity;
  final int? confidenceScore;
  final RiskLevel? riskLevel;
  final OpportunityPriority? priority;
  final DateTime? aiReviewedAt;

  // --- Opportunity Pipeline (Milestone 3.2) ---
  final OpportunityPipelineStage pipelineStage;
  final String? assignedTo;
  final String? reviewNotes;
  final String? qualificationNotes;
  final DateTime? submittedDate;
  final DateTime? decisionDate;
  final String? closedReason;
  final DateTime? lastStageUpdated;

  // --- AI Opportunity Match Analysis (Milestone 3.4) ---
  // Classification (3.1/3.3) answers "what is this opportunity"; these
  // fields answer "how well does JV ALMA CIS match it" — a separate AI
  // pass over the same Company Knowledge Graph. All nullable/empty by
  // default for the same reason as the 3.1 fields: nothing populates them
  // until `analyzeOpportunityMatch` is run — see ADR-004.
  final int? overallMatchScore;
  final int? businessUnitScore;
  final int? productScore;
  final int? serviceScore;
  final int? capabilityScore;
  final int? technologyScore;
  final int? industryScore;
  final int? experienceScore;
  final int? knowledgeScore;
  final String? strategicRecommendation;
  final List<String> recommendedProductIds;
  final List<String> recommendedBusinessUnitIds;
  final List<String> recommendedExperienceIds;
  final List<String> recommendedKnowledgeArticleIds;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> risks;
  final List<String> nextActions;
  final DateTime? matchAnalyzedAt;

  // --- AI Strategic Review (Milestone 3.5) ---
  // Classification (3.1/3.3) answers "what is this opportunity"; match
  // analysis (3.4) answers "how well do we match it"; these fields answer
  // the executive question "should we pursue it, and how" — a third AI
  // pass reasoning over the same Company Knowledge Graph plus the
  // classification/match-analysis fields above. Field names are prefixed
  // (`strategicReview*`/`strategic*`) to avoid colliding with 3.4's
  // already-existing `recommended*Ids`/`strengths`/`gaps`/`risks`/
  // `nextActions`/`strategicRecommendation` fields on this same document —
  // see ADR-005.
  final StrategicReviewRecommendation? executiveRecommendation;
  final String? executiveSummary;
  final List<String> strategicStrengths;
  final List<String> strategicWeaknesses;
  final List<String> strategicRisks;
  final List<String> mitigationStrategies;
  final List<String> competitiveAdvantages;
  final List<String> missingRequirements;
  final List<String> strategicReviewBusinessUnitIds;
  final List<String> strategicReviewProductIds;
  final List<String> strategicReviewServiceIds;
  final List<String> strategicReviewCapabilityIds;
  final List<String> strategicReviewTechnologyIds;
  final List<String> strategicReviewExperienceIds;
  final List<String> strategicReviewKnowledgeArticleIds;
  final String? proposalPositioningStrategy;
  final List<String> nextRecommendedActions;
  final DateTime? strategicReviewedAt;

  // --- Strategic Decision (Business Workflow Governance) ---
  // The AI's `executiveRecommendation` above is advisory and immutable —
  // this block is the separate, human-recorded business decision. Reuses
  // [StrategicReviewRecommendation] (pursue/pursueWithCaution/doNotPursue)
  // rather than a second enum, since the human is choosing from the same
  // conceptual options the AI reasoned about, just deciding rather than
  // recommending. Deliberately never overwrites `executiveRecommendation` —
  // the two can and often will disagree (e.g. AI says "Do Not Pursue," a
  // human decides "Pursue" anyway); both remain visible so the disagreement
  // itself is part of the record. Nothing in this codebase currently reads
  // `humanDecision` to gate Proposal/Submission creation — whether it
  // should is an open product decision, not assumed here.
  final StrategicReviewRecommendation? humanDecision;
  final String? humanDecisionReason;
  final String? humanDecisionBy;
  final DateTime? humanDecisionAt;

  // --- Certification eligibility requirements (Company Certifications) ---
  // Manually entered on the Opportunity Workspace's Eligibility section —
  // never auto-filled from `aiExtractedCertifications` or any other AI
  // extraction output (see `OpportunityCertificationRequirement`'s doc
  // comment). Checked against `certificationsStreamProvider` via
  // `computeEligibilityGaps` (`certification_eligibility.dart`) to render
  // gap chips; nothing here gates Proposal/Submission/Start Project.
  final List<OpportunityCertificationRequirement> requiredCertifications;

  const Opportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceUrl,
    this.sourceUrlVerified = false,
    this.sourceUrlVerifiedAt,
    this.sourceUrlIsFallback = false,
    this.lastNotifiedScore,
    this.matchNotificationSentAt,
    this.client,
    this.deadline,
    this.status = OpportunityStatus.discovered,
    this.procuringOrganization,
    this.tenderReferenceNumber,
    this.requiredTechnologies = const [],
    this.fitScorePercent = 0,
    this.fitReasoning = '',
    this.tags = const [],
    required this.discoveredAt,
    required this.updatedAt,
    this.discoverySourceId,
    this.discoverySourceType,
    this.geographyPriority,
    this.tenderSourceId,
    this.tenderSourceCategory,
    this.tenderDiscoveryMethod,
    this.classificationStatus = ClassificationStatus.notClassified,
    this.classificationSummary,
    this.industryIds = const [],
    this.technologyIds = const [],
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.serviceIds = const [],
    this.capabilityIds = const [],
    this.experienceIds = const [],
    this.knowledgeArticleIds = const [],
    this.opportunityType,
    this.estimatedBudget,
    this.estimatedDuration,
    this.estimatedComplexity,
    this.confidenceScore,
    this.riskLevel,
    this.priority,
    this.aiReviewedAt,
    this.pipelineStage = OpportunityPipelineStage.discovered,
    this.assignedTo,
    this.reviewNotes,
    this.qualificationNotes,
    this.submittedDate,
    this.decisionDate,
    this.closedReason,
    this.lastStageUpdated,
    this.overallMatchScore,
    this.businessUnitScore,
    this.productScore,
    this.serviceScore,
    this.capabilityScore,
    this.technologyScore,
    this.industryScore,
    this.experienceScore,
    this.knowledgeScore,
    this.strategicRecommendation,
    this.recommendedProductIds = const [],
    this.recommendedBusinessUnitIds = const [],
    this.recommendedExperienceIds = const [],
    this.recommendedKnowledgeArticleIds = const [],
    this.strengths = const [],
    this.gaps = const [],
    this.risks = const [],
    this.nextActions = const [],
    this.matchAnalyzedAt,
    this.executiveRecommendation,
    this.executiveSummary,
    this.strategicStrengths = const [],
    this.strategicWeaknesses = const [],
    this.strategicRisks = const [],
    this.mitigationStrategies = const [],
    this.competitiveAdvantages = const [],
    this.missingRequirements = const [],
    this.strategicReviewBusinessUnitIds = const [],
    this.strategicReviewProductIds = const [],
    this.strategicReviewServiceIds = const [],
    this.strategicReviewCapabilityIds = const [],
    this.strategicReviewTechnologyIds = const [],
    this.strategicReviewExperienceIds = const [],
    this.strategicReviewKnowledgeArticleIds = const [],
    this.proposalPositioningStrategy,
    this.nextRecommendedActions = const [],
    this.strategicReviewedAt,
    this.humanDecision,
    this.humanDecisionReason,
    this.humanDecisionBy,
    this.humanDecisionAt,
    this.requiredCertifications = const [],
  });

  factory Opportunity.fromMap(String id, Map<String, dynamic> map) {
    return Opportunity(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      sourceUrlVerified: map['sourceUrlVerified'] as bool? ?? false,
      sourceUrlVerifiedAt: (map['sourceUrlVerifiedAt'] as Timestamp?)?.toDate(),
      sourceUrlIsFallback: map['sourceUrlIsFallback'] as bool? ?? false,
      lastNotifiedScore: (map['lastNotifiedScore'] as num?)?.toInt(),
      matchNotificationSentAt: (map['matchNotificationSentAt'] as Timestamp?)
          ?.toDate(),
      client: map['client'] as String?,
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      status: OpportunityStatusX.fromString(
        map['status'] as String? ?? 'discovered',
      ),
      procuringOrganization: map['procuringOrganization'] as String?,
      tenderReferenceNumber: map['tenderReferenceNumber'] as String?,
      requiredTechnologies: List<String>.from(
        map['requiredTechnologies'] as List? ?? const [],
      ),
      fitScorePercent: (map['fitScorePercent'] as num?)?.toInt() ?? 0,
      fitReasoning: map['fitReasoning'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      discoveredAt:
          (map['discoveredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      discoverySourceId: map['discoverySourceId'] as String?,
      discoverySourceType: map['discoverySourceType'] != null
          ? DiscoverySourceTypeX.fromString(
              map['discoverySourceType'] as String,
            )
          : null,
      geographyPriority: map['geographyPriority'] != null
          ? GeographyPriorityX.fromString(map['geographyPriority'] as String)
          : null,
      tenderSourceId: map['tenderSourceId'] as String?,
      tenderSourceCategory: map['tenderSourceCategory'] != null
          ? TenderSourceCategory.values.firstWhere(
              (c) => c.name == map['tenderSourceCategory'],
              orElse: () => TenderSourceCategory.customEnterprise,
            )
          : null,
      tenderDiscoveryMethod: map['tenderDiscoveryMethod'] != null
          ? TenderDiscoveryMethod.values.firstWhere(
              (m) => m.name == map['tenderDiscoveryMethod'],
              orElse: () => TenderDiscoveryMethod.manual,
            )
          : null,
      classificationStatus: ClassificationStatusX.fromString(
        map['classificationStatus'] as String? ?? 'notClassified',
      ),
      classificationSummary: map['classificationSummary'] as String?,
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      experienceIds: List<String>.from(
        map['experienceIds'] as List? ?? const [],
      ),
      knowledgeArticleIds: List<String>.from(
        map['knowledgeArticleIds'] as List? ?? const [],
      ),
      opportunityType: map['opportunityType'] as String?,
      estimatedBudget: (map['estimatedBudget'] as num?)?.toDouble(),
      estimatedDuration: map['estimatedDuration'] as String?,
      estimatedComplexity: map['estimatedComplexity'] != null
          ? EstimatedComplexityX.fromString(
              map['estimatedComplexity'] as String,
            )
          : null,
      confidenceScore: (map['confidenceScore'] as num?)?.toInt(),
      riskLevel: map['riskLevel'] != null
          ? RiskLevelX.fromString(map['riskLevel'] as String)
          : null,
      priority: map['priority'] != null
          ? OpportunityPriorityX.fromString(map['priority'] as String)
          : null,
      aiReviewedAt: (map['aiReviewedAt'] as Timestamp?)?.toDate(),
      pipelineStage: OpportunityPipelineStageX.fromString(
        map['pipelineStage'] as String? ?? 'discovered',
      ),
      assignedTo: map['assignedTo'] as String?,
      reviewNotes: map['reviewNotes'] as String?,
      qualificationNotes: map['qualificationNotes'] as String?,
      submittedDate: (map['submittedDate'] as Timestamp?)?.toDate(),
      decisionDate: (map['decisionDate'] as Timestamp?)?.toDate(),
      closedReason: map['closedReason'] as String?,
      lastStageUpdated: (map['lastStageUpdated'] as Timestamp?)?.toDate(),
      overallMatchScore: (map['overallMatchScore'] as num?)?.toInt(),
      businessUnitScore: (map['businessUnitScore'] as num?)?.toInt(),
      productScore: (map['productScore'] as num?)?.toInt(),
      serviceScore: (map['serviceScore'] as num?)?.toInt(),
      capabilityScore: (map['capabilityScore'] as num?)?.toInt(),
      technologyScore: (map['technologyScore'] as num?)?.toInt(),
      industryScore: (map['industryScore'] as num?)?.toInt(),
      experienceScore: (map['experienceScore'] as num?)?.toInt(),
      knowledgeScore: (map['knowledgeScore'] as num?)?.toInt(),
      strategicRecommendation: map['strategicRecommendation'] as String?,
      recommendedProductIds: List<String>.from(
        map['recommendedProductIds'] as List? ?? const [],
      ),
      recommendedBusinessUnitIds: List<String>.from(
        map['recommendedBusinessUnitIds'] as List? ?? const [],
      ),
      recommendedExperienceIds: List<String>.from(
        map['recommendedExperienceIds'] as List? ?? const [],
      ),
      recommendedKnowledgeArticleIds: List<String>.from(
        map['recommendedKnowledgeArticleIds'] as List? ?? const [],
      ),
      strengths: List<String>.from(map['strengths'] as List? ?? const []),
      gaps: List<String>.from(map['gaps'] as List? ?? const []),
      risks: List<String>.from(map['risks'] as List? ?? const []),
      nextActions: List<String>.from(map['nextActions'] as List? ?? const []),
      matchAnalyzedAt: (map['matchAnalyzedAt'] as Timestamp?)?.toDate(),
      executiveRecommendation: map['executiveRecommendation'] != null
          ? StrategicReviewRecommendationX.fromString(
              map['executiveRecommendation'] as String,
            )
          : null,
      executiveSummary: map['executiveSummary'] as String?,
      strategicStrengths: List<String>.from(
        map['strategicStrengths'] as List? ?? const [],
      ),
      strategicWeaknesses: List<String>.from(
        map['strategicWeaknesses'] as List? ?? const [],
      ),
      strategicRisks: List<String>.from(
        map['strategicRisks'] as List? ?? const [],
      ),
      mitigationStrategies: List<String>.from(
        map['mitigationStrategies'] as List? ?? const [],
      ),
      competitiveAdvantages: List<String>.from(
        map['competitiveAdvantages'] as List? ?? const [],
      ),
      missingRequirements: List<String>.from(
        map['missingRequirements'] as List? ?? const [],
      ),
      strategicReviewBusinessUnitIds: List<String>.from(
        map['strategicReviewBusinessUnitIds'] as List? ?? const [],
      ),
      strategicReviewProductIds: List<String>.from(
        map['strategicReviewProductIds'] as List? ?? const [],
      ),
      strategicReviewServiceIds: List<String>.from(
        map['strategicReviewServiceIds'] as List? ?? const [],
      ),
      strategicReviewCapabilityIds: List<String>.from(
        map['strategicReviewCapabilityIds'] as List? ?? const [],
      ),
      strategicReviewTechnologyIds: List<String>.from(
        map['strategicReviewTechnologyIds'] as List? ?? const [],
      ),
      strategicReviewExperienceIds: List<String>.from(
        map['strategicReviewExperienceIds'] as List? ?? const [],
      ),
      strategicReviewKnowledgeArticleIds: List<String>.from(
        map['strategicReviewKnowledgeArticleIds'] as List? ?? const [],
      ),
      proposalPositioningStrategy:
          map['proposalPositioningStrategy'] as String?,
      nextRecommendedActions: List<String>.from(
        map['nextRecommendedActions'] as List? ?? const [],
      ),
      strategicReviewedAt: (map['strategicReviewedAt'] as Timestamp?)?.toDate(),
      humanDecision: map['humanDecision'] != null
          ? StrategicReviewRecommendationX.fromString(
              map['humanDecision'] as String,
            )
          : null,
      humanDecisionReason: map['humanDecisionReason'] as String?,
      humanDecisionBy: map['humanDecisionBy'] as String?,
      humanDecisionAt: (map['humanDecisionAt'] as Timestamp?)?.toDate(),
      requiredCertifications:
          (map['requiredCertifications'] as List<dynamic>? ?? const [])
              .map(
                (e) => OpportunityCertificationRequirement.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'sourceUrl': sourceUrl,
      'sourceUrlVerified': sourceUrlVerified,
      'sourceUrlVerifiedAt': sourceUrlVerifiedAt != null
          ? Timestamp.fromDate(sourceUrlVerifiedAt!)
          : null,
      'sourceUrlIsFallback': sourceUrlIsFallback,
      'lastNotifiedScore': lastNotifiedScore,
      'matchNotificationSentAt': matchNotificationSentAt != null
          ? Timestamp.fromDate(matchNotificationSentAt!)
          : null,
      'client': client,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'status': status.name,
      'procuringOrganization': procuringOrganization,
      'tenderReferenceNumber': tenderReferenceNumber,
      'requiredTechnologies': requiredTechnologies,
      'fitScorePercent': fitScorePercent,
      'fitReasoning': fitReasoning,
      'tags': tags,
      'discoveredAt': Timestamp.fromDate(discoveredAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'discoverySourceId': discoverySourceId,
      'discoverySourceType': discoverySourceType?.name,
      'geographyPriority': geographyPriority?.name,
      'tenderSourceId': tenderSourceId,
      'tenderSourceCategory': tenderSourceCategory?.name,
      'tenderDiscoveryMethod': tenderDiscoveryMethod?.name,
      'classificationStatus': classificationStatus.name,
      'classificationSummary': classificationSummary,
      'industryIds': industryIds,
      'technologyIds': technologyIds,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'serviceIds': serviceIds,
      'capabilityIds': capabilityIds,
      'experienceIds': experienceIds,
      'knowledgeArticleIds': knowledgeArticleIds,
      'opportunityType': opportunityType,
      'estimatedBudget': estimatedBudget,
      'estimatedDuration': estimatedDuration,
      'estimatedComplexity': estimatedComplexity?.name,
      'confidenceScore': confidenceScore,
      'riskLevel': riskLevel?.name,
      'priority': priority?.name,
      'aiReviewedAt': aiReviewedAt != null
          ? Timestamp.fromDate(aiReviewedAt!)
          : null,
      'pipelineStage': pipelineStage.name,
      'assignedTo': assignedTo,
      'reviewNotes': reviewNotes,
      'qualificationNotes': qualificationNotes,
      'submittedDate': submittedDate != null
          ? Timestamp.fromDate(submittedDate!)
          : null,
      'decisionDate': decisionDate != null
          ? Timestamp.fromDate(decisionDate!)
          : null,
      'closedReason': closedReason,
      'lastStageUpdated': lastStageUpdated != null
          ? Timestamp.fromDate(lastStageUpdated!)
          : null,
      'overallMatchScore': overallMatchScore,
      'businessUnitScore': businessUnitScore,
      'productScore': productScore,
      'serviceScore': serviceScore,
      'capabilityScore': capabilityScore,
      'technologyScore': technologyScore,
      'industryScore': industryScore,
      'experienceScore': experienceScore,
      'knowledgeScore': knowledgeScore,
      'strategicRecommendation': strategicRecommendation,
      'recommendedProductIds': recommendedProductIds,
      'recommendedBusinessUnitIds': recommendedBusinessUnitIds,
      'recommendedExperienceIds': recommendedExperienceIds,
      'recommendedKnowledgeArticleIds': recommendedKnowledgeArticleIds,
      'strengths': strengths,
      'gaps': gaps,
      'risks': risks,
      'nextActions': nextActions,
      'matchAnalyzedAt': matchAnalyzedAt != null
          ? Timestamp.fromDate(matchAnalyzedAt!)
          : null,
      'executiveRecommendation': executiveRecommendation?.name,
      'executiveSummary': executiveSummary,
      'strategicStrengths': strategicStrengths,
      'strategicWeaknesses': strategicWeaknesses,
      'strategicRisks': strategicRisks,
      'mitigationStrategies': mitigationStrategies,
      'competitiveAdvantages': competitiveAdvantages,
      'missingRequirements': missingRequirements,
      'strategicReviewBusinessUnitIds': strategicReviewBusinessUnitIds,
      'strategicReviewProductIds': strategicReviewProductIds,
      'strategicReviewServiceIds': strategicReviewServiceIds,
      'strategicReviewCapabilityIds': strategicReviewCapabilityIds,
      'strategicReviewTechnologyIds': strategicReviewTechnologyIds,
      'strategicReviewExperienceIds': strategicReviewExperienceIds,
      'strategicReviewKnowledgeArticleIds': strategicReviewKnowledgeArticleIds,
      'proposalPositioningStrategy': proposalPositioningStrategy,
      'nextRecommendedActions': nextRecommendedActions,
      'strategicReviewedAt': strategicReviewedAt != null
          ? Timestamp.fromDate(strategicReviewedAt!)
          : null,
      'humanDecision': humanDecision?.name,
      'humanDecisionReason': humanDecisionReason,
      'humanDecisionBy': humanDecisionBy,
      'humanDecisionAt': humanDecisionAt != null
          ? Timestamp.fromDate(humanDecisionAt!)
          : null,
      'requiredCertifications': requiredCertifications
          .map((r) => r.toMap())
          .toList(),
    };
  }
}
