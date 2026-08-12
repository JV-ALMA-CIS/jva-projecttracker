import 'package:cloud_firestore/cloud_firestore.dart';

enum IndustryStatus { active, archived }

extension IndustryStatusX on IndustryStatus {
  String get label => switch (this) {
    IndustryStatus.active => 'Active',
    IndustryStatus.archived => 'Archived',
  };

  static IndustryStatus fromString(String value) {
    return IndustryStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => IndustryStatus.active,
    );
  }
}

/// A market/industry vertical the company operates in or targets (e.g.
/// "Agriculture", "Water & Sanitation"). Sits downstream of Technologies in
/// the Company Intelligence knowledge graph being built up across
/// milestones: BusinessUnit -> Products -> Capabilities -> Technologies ->
/// Industries -> Experiences -> Opportunities. Every relationship below is a
/// flat doc-ID list — never an embedded object — so that chain can be
/// traversed by a future graph feature without a data migration.
/// `experienceIds` is included for the same forward-compatibility reason
/// even though the Experience entity doesn't exist yet.
class Industry {
  final String id;
  final String name;
  final String description;
  final String? sector;
  final List<String> tags;
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> capabilityIds;
  final List<String> technologyIds;
  final List<String> experienceIds;

  /// AI summary of this industry's application across the company
  /// (`generateIndustrySummary`), for the Industry Workspace header —
  /// mirrors `Technology.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final IndustryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Industry({
    required this.id,
    required this.name,
    this.description = '',
    this.sector,
    this.tags = const [],
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.capabilityIds = const [],
    this.technologyIds = const [],
    this.experienceIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    this.status = IndustryStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Industry.fromMap(String id, Map<String, dynamic> map) {
    return Industry(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      sector: map['sector'] as String?,
      tags: List<String>.from(map['tags'] as List? ?? const []),
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      experienceIds: List<String>.from(
        map['experienceIds'] as List? ?? const [],
      ),
      aiExpertiseSummary: map['aiExpertiseSummary'] as String?,
      aiExpertiseHighlights: List<String>.from(
        map['aiExpertiseHighlights'] as List? ?? const [],
      ),
      aiExpertiseSummaryGeneratedAt:
          (map['aiExpertiseSummaryGeneratedAt'] as Timestamp?)?.toDate(),
      status: IndustryStatusX.fromString(map['status'] as String? ?? 'active'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'sector': sector,
      'tags': tags,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'capabilityIds': capabilityIds,
      'technologyIds': technologyIds,
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
