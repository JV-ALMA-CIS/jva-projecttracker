import 'package:cloud_firestore/cloud_firestore.dart';

/// What kind of change a [ProjectEvent] records — enough to render a
/// sensible icon/verb, not a rich taxonomy.
enum ProjectEventType {
  statusChanged,
  milestoneCompleted,
  deliverableCompleted,
  deliverableBlocked,
  riskAdded,
  riskResolved,
  budgetUpdated,
  note,
}

extension ProjectEventTypeX on ProjectEventType {
  String get label => switch (this) {
    ProjectEventType.statusChanged => 'Status changed',
    ProjectEventType.milestoneCompleted => 'Milestone completed',
    ProjectEventType.deliverableCompleted => 'Deliverable completed',
    ProjectEventType.deliverableBlocked => 'Deliverable blocked',
    ProjectEventType.riskAdded => 'Risk added',
    ProjectEventType.riskResolved => 'Risk resolved',
    ProjectEventType.budgetUpdated => 'Budget updated',
    ProjectEventType.note => 'Note',
  };

  static ProjectEventType fromString(String value) {
    return ProjectEventType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ProjectEventType.note,
    );
  }
}

/// A single "recent activity" entry for a [Project] — its own collection
/// (`projectEvents`), keyed by `projectId`. Mirrors the existing
/// `OpportunityEvent` pattern (referenced in `PROJECT_PROGRESS.md`'s
/// technical-debt notes as the precedent a real audit trail should
/// follow) rather than inventing a new shape. Written by the relevant
/// service methods (e.g. `ProjectMilestoneService.markCompleted`,
/// `ProjectService.updateStatus`) — never edited by hand.
class ProjectEvent {
  final String id;
  final String projectId;
  final ProjectEventType type;
  final String summary;
  final String? actor;
  final DateTime occurredAt;

  const ProjectEvent({
    required this.id,
    required this.projectId,
    required this.type,
    required this.summary,
    this.actor,
    required this.occurredAt,
  });

  factory ProjectEvent.fromMap(String id, Map<String, dynamic> map) {
    return ProjectEvent(
      id: id,
      projectId: map['projectId'] as String? ?? '',
      type: ProjectEventTypeX.fromString(map['type'] as String? ?? 'note'),
      summary: map['summary'] as String? ?? '',
      actor: map['actor'] as String?,
      occurredAt: (map['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'type': type.name,
      'summary': summary,
      'actor': actor,
      'occurredAt': Timestamp.fromDate(occurredAt),
    };
  }
}
