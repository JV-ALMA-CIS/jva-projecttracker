import 'package:cloud_firestore/cloud_firestore.dart';

enum TechnologyStatus { active, archived }

extension TechnologyStatusX on TechnologyStatus {
  String get label => switch (this) {
    TechnologyStatus.active => 'Active',
    TechnologyStatus.archived => 'Archived',
  };

  static TechnologyStatus fromString(String value) {
    return TechnologyStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TechnologyStatus.active,
    );
  }
}

class Technology {
  final String id;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final String? category;
  final String? vendor;
  final String? website;
  final List<String> keywords;
  final List<String> tags;
  final TechnologyStatus status;
  final String? notes;

  /// Doc IDs into `businessUnits`/`products`/`capabilities`, in the same
  /// plain-reference-list shape used by every other Company Intelligence
  /// entity (see [BusinessUnit.productIds] etc.). Kept as flat ID lists
  /// rather than embedded objects so a future knowledge-graph feature can
  /// traverse these edges without a data migration.
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> capabilityIds;

  /// AI summary of this technology's application across the company
  /// (`generateTechnologySummary`), for the Technology Workspace header —
  /// mirrors `Product.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Technology({
    required this.id,
    required this.name,
    required this.slug,
    this.summary = '',
    this.description = '',
    this.category,
    this.vendor,
    this.website,
    this.keywords = const [],
    this.tags = const [],
    this.status = TechnologyStatus.active,
    this.notes,
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.capabilityIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Technology.fromMap(String id, Map<String, dynamic> map) {
    return Technology(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String?,
      vendor: map['vendor'] as String?,
      website: map['website'] as String?,
      keywords: List<String>.from(map['keywords'] as List? ?? const []),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      status: TechnologyStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      notes: map['notes'] as String?,
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
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
      'category': category,
      'vendor': vendor,
      'website': website,
      'keywords': keywords,
      'tags': tags,
      'status': status.name,
      'notes': notes,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'capabilityIds': capabilityIds,
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
