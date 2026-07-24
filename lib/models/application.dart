import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus { active, maintenance, deprecated }

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
    ApplicationStatus.active => 'Active',
    ApplicationStatus.maintenance => 'Maintenance',
    ApplicationStatus.deprecated => 'Deprecated',
  };

  static ApplicationStatus fromString(String value) {
    return ApplicationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ApplicationStatus.active,
    );
  }
}

/// A single AI-suggested market/usability area for an application, returned
/// transiently by the `discoverApplicationAreas` Cloud Function. Only the
/// `area` string is ever persisted (as an entry in
/// [CompanyApplication.applicationAreas]) — `reasoning` exists purely to
/// help the user decide whether to accept the suggestion.
class ApplicationAreaSuggestion {
  final String area;
  final String reasoning;

  const ApplicationAreaSuggestion({
    required this.area,
    required this.reasoning,
  });

  factory ApplicationAreaSuggestion.fromMap(Map<String, dynamic> map) {
    return ApplicationAreaSuggestion(
      area: map['area'] as String? ?? '',
      reasoning: map['reasoning'] as String? ?? '',
    );
  }
}

/// A company-developed application/system (e.g. coffeecore, almahub).
class CompanyApplication {
  final String id;
  final String name;
  final String description;
  final ApplicationStatus status;
  final List<String> platforms;
  final List<String> techStack;
  final String? repoUrl;
  final String? liveUrl;

  /// Candidate real-world application areas discovered via web search + Gemini,
  /// e.g. ["precision agriculture", "cooperative farm management"].
  final List<String> applicationAreas;
  final DateTime? applicationAreasUpdatedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyApplication({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.platforms = const [],
    this.techStack = const [],
    this.repoUrl,
    this.liveUrl,
    this.applicationAreas = const [],
    this.applicationAreasUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyApplication.fromMap(String id, Map<String, dynamic> map) {
    return CompanyApplication(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: ApplicationStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      platforms: List<String>.from(map['platforms'] as List? ?? const []),
      techStack: List<String>.from(map['techStack'] as List? ?? const []),
      repoUrl: map['repoUrl'] as String?,
      liveUrl: map['liveUrl'] as String?,
      applicationAreas: List<String>.from(
        map['applicationAreas'] as List? ?? const [],
      ),
      applicationAreasUpdatedAt:
          (map['applicationAreasUpdatedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'status': status.name,
      'platforms': platforms,
      'techStack': techStack,
      'repoUrl': repoUrl,
      'liveUrl': liveUrl,
      'applicationAreas': applicationAreas,
      'applicationAreasUpdatedAt': applicationAreasUpdatedAt != null
          ? Timestamp.fromDate(applicationAreasUpdatedAt!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
