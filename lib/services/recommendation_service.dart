import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/recommendation.dart';

const kRecommendationsCollection = 'recommendations';

/// Read/write access to the `recommendations` collection. Documents
/// themselves are normally created by the `generateRecommendations` Cloud
/// Function (see `RecommendationEngineService`) — `create` is exposed here
/// too for completeness/testability, matching every other service in this
/// codebase (e.g. `OpportunityEventService`).
class RecommendationService {
  RecommendationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(kRecommendationsCollection);

  /// Every recommendation, most recently generated first.
  Stream<List<Recommendation>> watchAll() {
    return _collection
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Recommendation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> create(Recommendation recommendation) async {
    final doc = await _collection.add(recommendation.toMap());
    return doc.id;
  }

  /// Narrow status-only update — mirrors
  /// `OpportunityService.updateStatus`. The user is choosing to ignore this
  /// recommendation, not editing the AI's underlying reasoning.
  Future<void> dismiss(String id) {
    return _collection.doc(id).update({
      'status': RecommendationStatus.dismissed.name,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Narrow status-only update — the user has acted on this recommendation
  /// (e.g. actually prioritized the opportunity it named).
  Future<void> markActioned(String id) {
    return _collection.doc(id).update({
      'status': RecommendationStatus.actioned.name,
      'updatedAt': Timestamp.now(),
    });
  }
}
