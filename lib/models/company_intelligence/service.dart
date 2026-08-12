import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceStatus { active, archived }

extension ServiceStatusX on ServiceStatus {
  String get label => switch (this) {
    ServiceStatus.active => 'Active',
    ServiceStatus.archived => 'Archived',
  };

  static ServiceStatus fromString(String value) {
    return ServiceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ServiceStatus.active,
    );
  }
}

class ServiceModel {
  final String id;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final List<String> businessUnitIds;
  final ServiceStatus status;
  final List<String> capabilityIds;
  final List<String> industryIds;
  final List<String> pastProjectIds;

  /// AI summary of this service's positioning (`generateServiceSummary`),
  /// for the Service Workspace header — mirrors
  /// `Product.aiExpertiseSummary`/`BusinessUnit.aiExpertiseSummary`.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.summary = '',
    this.description = '',
    this.businessUnitIds = const [],
    this.status = ServiceStatus.active,
    this.capabilityIds = const [],
    this.industryIds = const [],
    this.pastProjectIds = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceModel.fromMap(String id, Map<String, dynamic> map) {
    return ServiceModel(
      id: id,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      status: ServiceStatusX.fromString(map['status'] as String? ?? 'active'),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
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
      'businessUnitIds': businessUnitIds,
      'status': status.name,
      'capabilityIds': capabilityIds,
      'industryIds': industryIds,
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
