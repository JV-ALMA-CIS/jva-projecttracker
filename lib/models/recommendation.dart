import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// What kind of business insight a [Recommendation] represents — drives its
/// icon and grouping in the UI. See ADR-006.
enum RecommendationCategory {
  priorityOpportunity,
  atRiskOpportunity,
  capabilityGap,
  resourceAllocation,
  general,
}

extension RecommendationCategoryX on RecommendationCategory {
  String get label => switch (this) {
    RecommendationCategory.priorityOpportunity => 'Priority Opportunity',
    RecommendationCategory.atRiskOpportunity => 'At-Risk Opportunity',
    RecommendationCategory.capabilityGap => 'Capability Gap',
    RecommendationCategory.resourceAllocation => 'Resource Allocation',
    RecommendationCategory.general => 'General',
  };

  static RecommendationCategory fromString(String value) {
    return RecommendationCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => RecommendationCategory.general,
    );
  }
}

/// Where a recommendation sits in a user's triage workflow. `active` is a
/// live, unaddressed recommendation; `dismissed`/`actioned` are both
/// "resolved" but recorded distinctly so a user can tell what they ignored
/// apart from what they acted on.
enum RecommendationStatus { active, dismissed, actioned }

extension RecommendationStatusX on RecommendationStatus {
  String get label => switch (this) {
    RecommendationStatus.active => 'Active',
    RecommendationStatus.dismissed => 'Dismissed',
    RecommendationStatus.actioned => 'Actioned',
  };

  static RecommendationStatus fromString(String value) {
    return RecommendationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RecommendationStatus.active,
    );
  }
}

/// A single AI-generated, portfolio-wide business recommendation — e.g.
/// "fast-track this tender" or "invest in this capability" — produced by the
/// `generateRecommendations` Cloud Function reasoning over every
/// [Opportunity] plus the Company Knowledge Graph. Unlike the classification/
/// match-analysis/strategic-review fields on [Opportunity] (each scoped to
/// one opportunity), recommendations are their own top-level entity: a
/// single AI run can produce several, and any subset of them may or may not
/// reference a specific opportunity. See ADR-006.
class Recommendation {
  final String id;
  final RecommendationCategory category;

  /// Reuses [OpportunityPriority] rather than a duplicate low/medium/high
  /// enum — see ADR-006.
  final OpportunityPriority priority;
  final String title;
  final String reasoning;
  final int? confidenceScore;
  final RecommendationStatus status;
  final List<String> relatedOpportunityIds;
  final List<String> relatedBusinessUnitIds;
  final List<String> relatedProductIds;
  final List<String> relatedServiceIds;
  final List<String> relatedCapabilityIds;
  final List<String> relatedTechnologyIds;
  final List<String> relatedIndustryIds;
  final List<String> relatedExperienceIds;
  final List<String> relatedKnowledgeArticleIds;
  final DateTime generatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recommendation({
    required this.id,
    this.category = RecommendationCategory.general,
    this.priority = OpportunityPriority.medium,
    required this.title,
    required this.reasoning,
    this.confidenceScore,
    this.status = RecommendationStatus.active,
    this.relatedOpportunityIds = const [],
    this.relatedBusinessUnitIds = const [],
    this.relatedProductIds = const [],
    this.relatedServiceIds = const [],
    this.relatedCapabilityIds = const [],
    this.relatedTechnologyIds = const [],
    this.relatedIndustryIds = const [],
    this.relatedExperienceIds = const [],
    this.relatedKnowledgeArticleIds = const [],
    required this.generatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recommendation.fromMap(String id, Map<String, dynamic> map) {
    return Recommendation(
      id: id,
      category: RecommendationCategoryX.fromString(
        map['category'] as String? ?? 'general',
      ),
      priority: OpportunityPriorityX.fromString(
        map['priority'] as String? ?? 'medium',
      ),
      title: map['title'] as String? ?? '',
      reasoning: map['reasoning'] as String? ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toInt(),
      status: RecommendationStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      relatedOpportunityIds: List<String>.from(
        map['relatedOpportunityIds'] as List? ?? const [],
      ),
      relatedBusinessUnitIds: List<String>.from(
        map['relatedBusinessUnitIds'] as List? ?? const [],
      ),
      relatedProductIds: List<String>.from(
        map['relatedProductIds'] as List? ?? const [],
      ),
      relatedServiceIds: List<String>.from(
        map['relatedServiceIds'] as List? ?? const [],
      ),
      relatedCapabilityIds: List<String>.from(
        map['relatedCapabilityIds'] as List? ?? const [],
      ),
      relatedTechnologyIds: List<String>.from(
        map['relatedTechnologyIds'] as List? ?? const [],
      ),
      relatedIndustryIds: List<String>.from(
        map['relatedIndustryIds'] as List? ?? const [],
      ),
      relatedExperienceIds: List<String>.from(
        map['relatedExperienceIds'] as List? ?? const [],
      ),
      relatedKnowledgeArticleIds: List<String>.from(
        map['relatedKnowledgeArticleIds'] as List? ?? const [],
      ),
      generatedAt:
          (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'priority': priority.name,
      'title': title,
      'reasoning': reasoning,
      'confidenceScore': confidenceScore,
      'status': status.name,
      'relatedOpportunityIds': relatedOpportunityIds,
      'relatedBusinessUnitIds': relatedBusinessUnitIds,
      'relatedProductIds': relatedProductIds,
      'relatedServiceIds': relatedServiceIds,
      'relatedCapabilityIds': relatedCapabilityIds,
      'relatedTechnologyIds': relatedTechnologyIds,
      'relatedIndustryIds': relatedIndustryIds,
      'relatedExperienceIds': relatedExperienceIds,
      'relatedKnowledgeArticleIds': relatedKnowledgeArticleIds,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
