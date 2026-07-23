import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { planned, running, past }

extension ProjectStatusX on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.planned => 'Planned',
    ProjectStatus.running => 'Running',
    ProjectStatus.past => 'Past',
  };

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProjectStatus.planned,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String client;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> techStack;
  final List<String> teamMembers;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.client,
    required this.status,
    this.startDate,
    this.endDate,
    this.techStack = const [],
    this.teamMembers = const [],
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    return Project(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      client: map['client'] as String? ?? '',
      status: ProjectStatusX.fromString(map['status'] as String? ?? 'planned'),
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      techStack: List<String>.from(map['techStack'] as List? ?? const []),
      teamMembers: List<String>.from(map['teamMembers'] as List? ?? const []),
      notes: map['notes'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'client': client,
      'status': status.name,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'techStack': techStack,
      'teamMembers': teamMembers,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Project copyWith({
    String? name,
    String? description,
    String? client,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? techStack,
    List<String>? teamMembers,
    String? notes,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      client: client ?? this.client,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      techStack: techStack ?? this.techStack,
      teamMembers: teamMembers ?? this.teamMembers,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
