import 'package:cloud_firestore/cloud_firestore.dart';

enum KnowledgeArticleStatus { active, archived }

extension KnowledgeArticleStatusX on KnowledgeArticleStatus {
  String get label => switch (this) {
    KnowledgeArticleStatus.active => 'Active',
    KnowledgeArticleStatus.archived => 'Archived',
  };

  static KnowledgeArticleStatus fromString(String value) {
    return KnowledgeArticleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => KnowledgeArticleStatus.active,
    );
  }
}

/// Starter categories offered as quick-pick suggestions in the article form.
/// Deliberately not an enum: [KnowledgeArticle.category] is a plain string,
/// so a new category can be introduced just by typing it in — no code
/// change or redeploy needed.
const List<String> suggestedKnowledgeCategories = [
  'Company Overview',
  'Methodology',
  'Standard Operating Procedure',
  'Implementation Process',
  'Best Practice',
  'Technical Knowledge',
  'Lessons Learned',
  'Proposal Guidance',
  'Industry Knowledge',
  'General Knowledge',
];

/// A structured knowledge-base entry — not a document management system (no
/// file uploads/attachments), but text content written for a future AI
/// (opportunity classification/scoring, proposal generation, strategic
/// reasoning) rather than for human file storage.
///
/// Every relationship below is a flat doc-ID list, the same convention as
/// every other Company Intelligence entity, so an article can cross-
/// reference any part of the knowledge graph
/// (BusinessUnit/Product/Service/Capability/Technology/Industry/Experience)
/// without a migration once a graph feature reads it.
class KnowledgeArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String content;
  final List<String> tags;
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> technologyIds;
  final List<String> industryIds;
  final List<String> experienceIds;

  /// AI summary distilling this article's practical relevance across the
  /// company (`generateKnowledgeArticleSummary`), for the Knowledge
  /// Article Workspace header — mirrors `Experience.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final KnowledgeArticleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeArticle({
    required this.id,
    required this.title,
    this.category = '',
    this.summary = '',
    this.content = '',
    this.tags = const [],
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.serviceIds = const [],
    this.capabilityIds = const [],
    this.technologyIds = const [],
    this.industryIds = const [],
    this.experienceIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    this.status = KnowledgeArticleStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnowledgeArticle.fromMap(String id, Map<String, dynamic> map) {
    return KnowledgeArticle(
      id: id,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      content: map['content'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      experienceIds: List<String>.from(
        map['experienceIds'] as List? ?? const [],
      ),
      aiExpertiseSummary: map['aiExpertiseSummary'] as String?,
      aiExpertiseHighlights: List<String>.from(
        map['aiExpertiseHighlights'] as List? ?? const [],
      ),
      aiExpertiseSummaryGeneratedAt:
          (map['aiExpertiseSummaryGeneratedAt'] as Timestamp?)?.toDate(),
      status: KnowledgeArticleStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'summary': summary,
      'content': content,
      'tags': tags,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'serviceIds': serviceIds,
      'capabilityIds': capabilityIds,
      'technologyIds': technologyIds,
      'industryIds': industryIds,
      'experienceIds': experienceIds,
      'aiExpertiseSummary': aiExpertiseSummary,
      'aiExpertiseHighlights': aiExpertiseHighlights,
      'aiExpertiseSummaryGeneratedAt': aiExpertiseSummaryGeneratedAt != null
          ? Timestamp.fromDate(aiExpertiseSummaryGeneratedAt!)
          : null,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
