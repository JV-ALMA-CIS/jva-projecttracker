import 'package:cloud_firestore/cloud_firestore.dart';

/// A milestone's state is derived, not stored as a separate enum — it
/// depends only on [ProjectMilestone.completedAt] vs [ProjectMilestone.dueDate]
/// vs "now", so there is exactly one source of truth for "is this late"
/// rather than a status field that can drift out of sync with the dates.
enum ProjectMilestoneState { upcoming, dueSoon, delayed, completed }

/// One milestone on a [Project]'s delivery timeline. Its own collection
/// (`projectMilestones`), keyed by `projectId`, per this project's "never
/// embed entire objects" rule — same shape as `ProposalSection` relative
/// to `Proposal`.
class ProjectMilestone {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int order;

  /// IDs of other [ProjectMilestone]s this one depends on — the
  /// "dependencies" the brief asks the Timeline to show. Plain ID list,
  /// same relationship convention as everywhere else in this app.
  final List<String> dependsOnMilestoneIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectMilestone({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.completedAt,
    this.order = 0,
    this.dependsOnMilestoneIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Derived state — see class doc comment for why this isn't stored.
  ProjectMilestoneState state({DateTime? now}) {
    if (completedAt != null) return ProjectMilestoneState.completed;
    final today = now ?? DateTime.now();
    if (dueDate == null) return ProjectMilestoneState.upcoming;
    if (dueDate!.isBefore(today)) return ProjectMilestoneState.delayed;
    if (dueDate!.difference(today).inDays <= 7) {
      return ProjectMilestoneState.dueSoon;
    }
    return ProjectMilestoneState.upcoming;
  }

  factory ProjectMilestone.fromMap(String id, Map<String, dynamic> map) {
    return ProjectMilestone(
      id: id,
      projectId: map['projectId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      order: (map['order'] as num?)?.toInt() ?? 0,
      dependsOnMilestoneIds: List<String>.from(
        map['dependsOnMilestoneIds'] as List? ?? const [],
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'order': order,
      'dependsOnMilestoneIds': dependsOnMilestoneIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
