import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskSeverity { low, medium, high, critical }

extension RiskSeverityX on RiskSeverity {
  String get label => switch (this) {
    RiskSeverity.low => 'Low',
    RiskSeverity.medium => 'Medium',
    RiskSeverity.high => 'High',
    RiskSeverity.critical => 'Critical',
  };

  /// A plain 1-4 weight — used only to rank risks by severity×likelihood
  /// for the "AI should prioritize the most critical risks" requirement.
  /// This is ordinary arithmetic on fields the user themselves set, not a
  /// new AI model, per this project's "reuse existing AI infra, don't
  /// invent new models" constraint.
  int get weight => switch (this) {
    RiskSeverity.low => 1,
    RiskSeverity.medium => 2,
    RiskSeverity.high => 3,
    RiskSeverity.critical => 4,
  };

  static RiskSeverity fromString(String value) {
    return RiskSeverity.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RiskSeverity.medium,
    );
  }
}

enum RiskLikelihood { low, medium, high }

extension RiskLikelihoodX on RiskLikelihood {
  String get label => switch (this) {
    RiskLikelihood.low => 'Low',
    RiskLikelihood.medium => 'Medium',
    RiskLikelihood.high => 'High',
  };

  int get weight => switch (this) {
    RiskLikelihood.low => 1,
    RiskLikelihood.medium => 2,
    RiskLikelihood.high => 3,
  };

  static RiskLikelihood fromString(String value) {
    return RiskLikelihood.values.firstWhere(
      (l) => l.name == value,
      orElse: () => RiskLikelihood.medium,
    );
  }
}

enum RiskStatus { open, mitigated, closed }

extension RiskStatusX on RiskStatus {
  String get label => switch (this) {
    RiskStatus.open => 'Open',
    RiskStatus.mitigated => 'Mitigated',
    RiskStatus.closed => 'Closed',
  };

  static RiskStatus fromString(String value) {
    return RiskStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RiskStatus.open,
    );
  }
}

/// A risk tracked against a [Project] — its own collection
/// (`projectRisks`), keyed by `projectId`. [mitigationActions] is a plain
/// list of free-text actions rather than its own collection: unlike
/// Milestones/Deliverables/Risks, mitigation steps for one risk are a
/// short, tightly-scoped list edited as a unit alongside the risk itself,
/// not independently queried or reported on — the same reasoning that
/// already justifies `Opportunity.nextActions` being a plain
/// `List<String>` rather than its own collection.
class ProjectRisk {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final RiskSeverity severity;
  final RiskLikelihood likelihood;
  final RiskStatus status;
  final String? owner;
  final List<String> mitigationActions;
  final DateTime? identifiedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectRisk({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.severity = RiskSeverity.medium,
    this.likelihood = RiskLikelihood.medium,
    this.status = RiskStatus.open,
    this.owner,
    this.mitigationActions = const [],
    this.identifiedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// severity.weight × likelihood.weight — the plain-arithmetic priority
  /// rank the Risks panel sorts by (see [RiskSeverityX.weight] doc comment).
  int get priorityRank => severity.weight * likelihood.weight;

  factory ProjectRisk.fromMap(String id, Map<String, dynamic> map) {
    return ProjectRisk(
      id: id,
      projectId: map['projectId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      severity: RiskSeverityX.fromString(
        map['severity'] as String? ?? 'medium',
      ),
      likelihood: RiskLikelihoodX.fromString(
        map['likelihood'] as String? ?? 'medium',
      ),
      status: RiskStatusX.fromString(map['status'] as String? ?? 'open'),
      owner: map['owner'] as String?,
      mitigationActions: List<String>.from(
        map['mitigationActions'] as List? ?? const [],
      ),
      identifiedAt: (map['identifiedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'severity': severity.name,
      'likelihood': likelihood.name,
      'status': status.name,
      'owner': owner,
      'mitigationActions': mitigationActions,
      'identifiedAt': identifiedAt != null
          ? Timestamp.fromDate(identifiedAt!)
          : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
