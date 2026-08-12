import 'package:cloud_firestore/cloud_firestore.dart';

enum ExperienceStatus { active, archived }

extension ExperienceStatusX on ExperienceStatus {
  String get label => switch (this) {
    ExperienceStatus.active => 'Active',
    ExperienceStatus.archived => 'Archived',
  };

  static ExperienceStatus fromString(String value) {
    return ExperienceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ExperienceStatus.active,
    );
  }
}

/// A completed (or in-progress) real-world engagement — the evidentiary
/// core of the Company Intelligence knowledge graph. Every relationship
/// below is a flat doc-ID list, never an embedded object, so a future AI
/// opportunity-scoring/proposal-generation feature can traverse
/// BusinessUnit -> Products -> Capabilities -> Technologies -> Industries ->
/// Experiences -> Opportunities without a data migration. `Opportunity`
/// doesn't reference `Experience` yet — that link lands when Opportunities
/// gain their own `experienceIds` field in a future milestone.
class Experience {
  final String id;
  final String title;
  final String summary;
  final String? clientName;
  final String? partnerName;
  final String? country;
  final String? region;
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> capabilityIds;
  final List<String> technologyIds;
  final List<String> industryIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? contractValue;
  final String currency;
  final String? fundingSource;
  final String outcome;
  final List<String> achievements;
  final List<String> lessonsLearned;
  final List<String> tags;

  /// AI summary distilling this experience into a polished, reusable
  /// narrative (`generateExperienceSummary`), for the Experience Workspace
  /// header — mirrors `Industry.aiExpertiseSummary`. Unlike other Company
  /// Intelligence entities, Experience already carries rich narrative
  /// fields of its own ([outcome], [achievements], [lessonsLearned]); the
  /// AI summary synthesizes those plus the graph context into one
  /// executive-readable paragraph, not a from-scratch invention.
  final String? aiExpertiseSummary;
  final List<String> aiExpertiseHighlights;
  final DateTime? aiExpertiseSummaryGeneratedAt;

  final ExperienceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Experience({
    required this.id,
    required this.title,
    this.summary = '',
    this.clientName,
    this.partnerName,
    this.country,
    this.region,
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.capabilityIds = const [],
    this.technologyIds = const [],
    this.industryIds = const [],
    this.startDate,
    this.endDate,
    this.contractValue,
    this.currency = 'EUR',
    this.fundingSource,
    this.outcome = '',
    this.achievements = const [],
    this.lessonsLearned = const [],
    this.tags = const [],
    this.aiExpertiseSummary,
    this.aiExpertiseHighlights = const [],
    this.aiExpertiseSummaryGeneratedAt,
    this.status = ExperienceStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Experience.fromMap(String id, Map<String, dynamic> map) {
    return Experience(
      id: id,
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      clientName: map['clientName'] as String?,
      partnerName: map['partnerName'] as String?,
      country: map['country'] as String?,
      region: map['region'] as String?,
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
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      contractValue: (map['contractValue'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'EUR',
      fundingSource: map['fundingSource'] as String?,
      outcome: map['outcome'] as String? ?? '',
      achievements: List<String>.from(map['achievements'] as List? ?? const []),
      lessonsLearned: List<String>.from(
        map['lessonsLearned'] as List? ?? const [],
      ),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      aiExpertiseSummary: map['aiExpertiseSummary'] as String?,
      aiExpertiseHighlights: List<String>.from(
        map['aiExpertiseHighlights'] as List? ?? const [],
      ),
      aiExpertiseSummaryGeneratedAt:
          (map['aiExpertiseSummaryGeneratedAt'] as Timestamp?)?.toDate(),
      status: ExperienceStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'clientName': clientName,
      'partnerName': partnerName,
      'country': country,
      'region': region,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'capabilityIds': capabilityIds,
      'technologyIds': technologyIds,
      'industryIds': industryIds,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'contractValue': contractValue,
      'currency': currency,
      'fundingSource': fundingSource,
      'outcome': outcome,
      'achievements': achievements,
      'lessonsLearned': lessonsLearned,
      'tags': tags,
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
