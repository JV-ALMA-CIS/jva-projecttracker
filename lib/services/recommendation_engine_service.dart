import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode
/// `RecommendationEngineService.generateRecommendations` can hit — API
/// failures, timeouts, invalid model output — so the UI layer only ever
/// needs to catch one exception type and show its message. Mirrors
/// `StrategicReviewException` from Milestone 3.5.
class RecommendationEngineException implements Exception {
  const RecommendationEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateRecommendations` Cloud Function, which runs Gemini
/// against every [Opportunity] (including their already-computed
/// classification/match-analysis/strategic-review fields) plus the Company
/// Knowledge Graph, and writes new documents directly into the
/// `recommendations` collection (see `functions/index.js`) — the live
/// `recommendationsStreamProvider` stream picks those up on its own. Unlike
/// `AIClassificationService`/`MatchAnalysisService`/`StrategicReviewService`,
/// this doesn't parse/return a rich result: like
/// `OpportunityService.triggerDiscoveryRun`, the Cloud Function creates a
/// batch of new documents and the client only needs the count for a
/// snackbar, so there's no parser file here — see ADR-006.
class RecommendationEngineService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved at
  /// all. Production code never sets it.
  RecommendationEngineService({
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>?> Function()? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<Map<String, dynamic>?> Function()? _invokeOverride;

  // Resolved lazily — constructing this with only invokeOverride set (the
  // shape every test in this app uses) must not require Firebase Core to
  // be initialized.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _invoke() {
    final override = _invokeOverride;
    if (override != null) return override();
    return _callCloudFunction();
  }

  Future<Map<String, dynamic>?> _callCloudFunction() async {
    final callable = _functions.httpsCallable(
      'generateRecommendations',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>();
    return response.data;
  }

  /// Returns the number of new recommendations created.
  Future<int> generateRecommendations() async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke();
    } on FirebaseFunctionsException catch (e) {
      throw RecommendationEngineException(_messageForFunctionsException(e));
    } catch (e) {
      // Callers (AppStrings.recommendationsRefreshFailed) already add a
      // "Refreshing recommendations failed:" framing — this message stays
      // just the underlying fact, so the two don't stack into a doubled-up
      // sentence.
      throw RecommendationEngineException('$e');
    }

    return (raw?['created'] as num?)?.toInt() ?? 0;
  }

  /// Every branch returns a lowercase-leading fragment, not a full sentence
  /// — see the comment above on why (avoids doubling up with the caller's
  /// own prefix).
  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
