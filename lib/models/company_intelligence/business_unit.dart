import 'package:cloud_firestore/cloud_firestore.dart';

enum BusinessUnitStatus { active, archived }

extension BusinessUnitStatusX on BusinessUnitStatus {
  String get label => switch (this) {
    BusinessUnitStatus.active => 'Active',
    BusinessUnitStatus.archived => 'Archived',
  };

  static BusinessUnitStatus fromString(String value) {
    return BusinessUnitStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => BusinessUnitStatus.active,
    );
  }
}

class BusinessUnit {
  final String id;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final BusinessUnitStatus status;
  final List<String> productIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> industryIds;
  final List<String> technologyIds;
  final List<String> pastProjectIds;

  /// AI summary of expertise (`generateBusinessUnitSummary`), for the
  /// Business Unit Workspace header — derived only from this BU's own
  /// linked products/services/technologies/industries/experiences/projects,
  /// `null` until first generated.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessUnit({
    required this.id,
    required this.name,
    required this.slug,
    this.summary = '',
    this.description = '',
    this.status = BusinessUnitStatus.active,
    this.productIds = const [],
    this.serviceIds = const [],
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

  factory BusinessUnit.fromMap(String id, Map<String, dynamic> map) {
    return BusinessUnit(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: BusinessUnitStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
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
      'status': status.name,
      'productIds': productIds,
      'serviceIds': serviceIds,
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

  BusinessUnit copyWith({
    String? id,
    String? name,
    String? slug,
    String? summary,
    String? description,
    BusinessUnitStatus? status,
    List<String>? productIds,
    List<String>? serviceIds,
    List<String>? capabilityIds,
    List<String>? industryIds,
    List<String>? technologyIds,
    List<String>? pastProjectIds,
    String? aiExpertiseSummary,
    List<String>? aiExpertiseHighlights,
    DateTime? aiExpertiseSummaryGeneratedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      status: status ?? this.status,
      productIds: productIds ?? this.productIds,
      serviceIds: serviceIds ?? this.serviceIds,
      capabilityIds: capabilityIds ?? this.capabilityIds,
      industryIds: industryIds ?? this.industryIds,
      technologyIds: technologyIds ?? this.technologyIds,
      pastProjectIds: pastProjectIds ?? this.pastProjectIds,
      aiExpertiseSummary: aiExpertiseSummary ?? this.aiExpertiseSummary,
      aiExpertiseHighlights:
          aiExpertiseHighlights ?? this.aiExpertiseHighlights,
      aiExpertiseSummaryGeneratedAt:
          aiExpertiseSummaryGeneratedAt ?? this.aiExpertiseSummaryGeneratedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
