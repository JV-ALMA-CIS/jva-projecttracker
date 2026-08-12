import 'package:cloud_firestore/cloud_firestore.dart';

/// A deliverable's lifecycle. `blocked` is the one state that can't be
/// derived purely from dates — it needs an explicit reason (see
/// [ProjectDeliverable.blockedReason]), so unlike [ProjectMilestoneState]
/// this one genuinely is stored, not derived.
enum ProjectDeliverableStatus { pending, completed, blocked }

extension ProjectDeliverableStatusX on ProjectDeliverableStatus {
  String get label => switch (this) {
    ProjectDeliverableStatus.pending => 'Pending',
    ProjectDeliverableStatus.completed => 'Completed',
    ProjectDeliverableStatus.blocked => 'Blocked',
  };

  static ProjectDeliverableStatus fromString(String value) {
    return ProjectDeliverableStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProjectDeliverableStatus.pending,
    );
  }
}

/// One deliverable on a [Project] — its own collection
/// (`projectDeliverables`), keyed by `projectId`, optionally grouped under
/// a [ProjectMilestone] via [milestoneId]. "Overdue" is derived from
/// [dueDate] vs now (same reasoning as [ProjectMilestoneState]) rather than
/// stored, so it can never drift out of sync with the date.
class ProjectDeliverable {
  final String id;
  final String projectId;
  final String? milestoneId;
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final ProjectDeliverableStatus status;
  final String? assignedTo;

  /// Required when [status] is [ProjectDeliverableStatus.blocked] — an
  /// honest "why," not just a status flag, per this app's AI Design
  /// Philosophy of always explaining WHY.
  final String? blockedReason;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectDeliverable({
    required this.id,
    required this.projectId,
    this.milestoneId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.completedAt,
    this.status = ProjectDeliverableStatus.pending,
    this.assignedTo,
    this.blockedReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue =>
      status != ProjectDeliverableStatus.completed &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  factory ProjectDeliverable.fromMap(String id, Map<String, dynamic> map) {
    return ProjectDeliverable(
      id: id,
      projectId: map['projectId'] as String? ?? '',
      milestoneId: map['milestoneId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      status: ProjectDeliverableStatusX.fromString(
        map['status'] as String? ?? 'pending',
      ),
      assignedTo: map['assignedTo'] as String?,
      blockedReason: map['blockedReason'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'milestoneId': milestoneId,
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'status': status.name,
      'assignedTo': assignedTo,
      'blockedReason': blockedReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
