import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductStatus { active, archived }

extension ProductStatusX on ProductStatus {
  String get label => switch (this) {
    ProductStatus.active => 'Active',
    ProductStatus.archived => 'Archived',
  };

  static ProductStatus fromString(String value) {
    return ProductStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProductStatus.active,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final String businessUnitId;
  final ProductStatus status;

  /// Optional link to where this product is listed/deployed (Play Store,
  /// App Store, a marketing site, an internal deployment URL, …) — purely
  /// informational, shown as a tappable link on the Product Workspace.
  /// Distinct from [slug], which is an internal id-safe identifier, never a
  /// public URL itself.
  final String? storeUrl;
  final List<String> capabilityIds;
  final List<String> industryIds;
  final List<String> technologyIds;
  final List<String> pastProjectIds;

  /// AI summary of this product's positioning (`generateProductSummary`),
  /// for the Product Workspace header — derived only from this product's
  /// own linked capabilities/technologies/industries/experiences/projects,
  /// `null` until first generated. Mirrors `BusinessUnit.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.slug,
    this.summary = '',
    this.description = '',
    required this.businessUnitId,
    this.status = ProductStatus.active,
    this.storeUrl,
    this.capabilityIds = const [],
    this.industryIds = const [],
    this.technologyIds = const [],
    this.pastProjectIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      businessUnitId: map['businessUnitId'] as String? ?? '',
      status: ProductStatusX.fromString(map['status'] as String? ?? 'active'),
      storeUrl: map['storeUrl'] as String?,
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      pastProjectIds: List<String>.from(
        map['pastProjectIds'] as List? ?? const [],
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
      'businessUnitId': businessUnitId,
      'status': status.name,
      'storeUrl': storeUrl,
      'capabilityIds': capabilityIds,
      'industryIds': industryIds,
      'technologyIds': technologyIds,
      'pastProjectIds': pastProjectIds,
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
