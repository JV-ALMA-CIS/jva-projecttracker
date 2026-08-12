import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/models/executive_summary.dart';

/// Thrown by [ExecutiveIntelligenceService.generateSummary] — mirrors
/// [StrategicReviewException]/[MatchAnalysisException]'s shape so
/// `strings.executiveSummaryFailed(e)` can format it the same way every
/// other AI-action failure is formatted.
class ExecutiveIntelligenceException implements Exception {
  final String message;
  const ExecutiveIntelligenceException(this.message);

  @override
  String toString() => message;
}

/// The AI Executive Summary is a single document — `analytics/
/// executiveSummary` — not a per-opportunity field, since it reasons over
/// the whole portfolio at once (see [ExecutiveSummary]). This service only
/// watches/regenerates that document; the rest of the Executive Dashboard's
/// KPIs are plain client-side derivations (`executive_analytics.dart`) and
/// need no service of their own.
class ExecutiveIntelligenceService {
  ExecutiveIntelligenceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('analytics').doc('executiveSummary');

  /// Live updates of the current AI Executive Summary. Emits an empty
  /// [ExecutiveSummary] (see [ExecutiveSummary.isEmpty]) until the first
  /// generation has ever run — an honest empty state, same convention as
  /// the Proposal Workspace's "Document Readiness" panel before Milestone
  /// 4.3.
  Stream<ExecutiveSummary> watch() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return const ExecutiveSummary();
      return ExecutiveSummary.fromMap(data);
    });
  }

  /// Calls the `generateExecutiveSummary` Cloud Function, which reasons over
  /// the full opportunity portfolio and Company Knowledge Graph and writes
  /// the result back onto the same singleton document [watch] streams.
  Future<void> generateSummary() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable(
            'generateExecutiveSummary',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call();
    } on FirebaseFunctionsException catch (e) {
      throw ExecutiveIntelligenceException(
        e.message ?? 'AI executive summary generation failed.',
      );
    }
  }
}
