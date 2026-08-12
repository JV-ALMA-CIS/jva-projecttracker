import 'package:cloud_firestore/cloud_firestore.dart';

enum CapabilityStatus { active, archived }

extension CapabilityStatusX on CapabilityStatus {
  String get label => switch (this) {
    CapabilityStatus.active => 'Active',
    CapabilityStatus.archived => 'Archived',
  };

  static CapabilityStatus fromString(String value) {
    return CapabilityStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CapabilityStatus.active,
    );
  }
}

class Capability {
  final String id;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final List<String> keywords;
  final List<String> tags;
  final CapabilityStatus status;
  final String? businessRelevance;
  final List<String> productIds;
  final List<String> serviceIds;

  /// AI summary of this capability's application across the company
  /// (`generateCapabilitySummary`), for the Capability Workspace header —
  /// mirrors `Product.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Capability({
    required this.id,
    required this.name,
    required this.slug,
    this.summary = '',
    this.description = '',
    this.keywords = const [],
    this.tags = const [],
    this.status = CapabilityStatus.active,
    this.businessRelevance,
    this.productIds = const [],
    this.serviceIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Capability.fromMap(String id, Map<String, dynamic> map) {
    return Capability(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      keywords: List<String>.from(map['keywords'] as List? ?? const []),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      status: CapabilityStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      businessRelevance: map['businessRelevance'] as String?,
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
      aiExpertiseSummary: map['aiExpertiseSummary'] as String?,
      aiExpertiseHighlights: List<String>.from(
        map['aiExpertiseHighlights'] as List? ?? const [],
      ),
      aiExpertiseSummaryGeneratedAt:
          (map['aiExpertiseSummaryGeneratedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'summary': summary,
      'description': description,
      'keywords': keywords,
      'tags': tags,
      'status': status.name,
      'businessRelevance': businessRelevance,
      'productIds': productIds,
      'serviceIds': serviceIds,
      'aiExpertiseSummary': aiExpertiseSummary,
      'aiExpertiseHighlights': aiExpertiseHighlights,
      'aiExpertiseSummaryGeneratedAt': aiExpertiseSummaryGeneratedAt != null
          ? Timestamp.fromDate(aiExpertiseSummaryGeneratedAt!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
