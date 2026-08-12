import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/project_event.dart';

/// Append-only — there is deliberately no `update`/`delete` here. Events
/// are a history log, not an editable record, same as
/// `OpportunityEventService` this mirrors.
class ProjectEventService {
  ProjectEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projectEvents');

  /// Most recent first, capped at [limit] — a "recent activity" feed, not
  /// a full paginated history.
  Stream<List<ProjectEvent>> watchByProjectId(
    String projectId, {
    int limit = 20,
  }) {
    return _collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ProjectEvent.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> log(ProjectEvent event) {
    return _collection.add(event.toMap());
  }
}
