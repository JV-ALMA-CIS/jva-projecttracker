import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `DiscoveryEngineService.runSource` can hit
/// — API failures, timeouts, or a source type with no automated adapter yet
/// — so the UI layer only ever needs to catch one exception type and show
/// its message. Mirrors `RecommendationEngineException`/
/// `StrategicReviewException`.
class DiscoveryEngineException implements Exception {
  const DiscoveryEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `runDiscoverySource` Cloud Function, which dispatches to the
/// adapter registered for the source's [DiscoverySourceType] (see
/// `functions/index.js`'s `DISCOVERY_ADAPTERS` registry), bookends the
/// attempt with a `discoveryRuns` document, and writes any new opportunities
/// directly to Firestore — the live `opportunitiesStreamProvider`/
/// `discoveryRunsStreamProvider` streams pick those up on their own. Like
/// `RecommendationEngineService`, only a count is returned for an immediate
/// snackbar; no parser file is needed. See the Opportunity Discovery Engine
/// (Milestone 3.7).
class DiscoveryEngineService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved at
  /// all. Production code never sets it.
  DiscoveryEngineService({
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>?> Function({required String sourceId})?
    invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<Map<String, dynamic>?> Function({required String sourceId})?
  _invokeOverride;

  // Resolved lazily — constructing this with only invokeOverride set (the
  // shape every test in this app uses) must not require Firebase Core to
  // be initialized.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _invoke(String sourceId) {
    final override = _invokeOverride;
    if (override != null) return override(sourceId: sourceId);
    return _callCloudFunction(sourceId);
  }

  Future<Map<String, dynamic>?> _callCloudFunction(String sourceId) async {
    final callable = _functions.httpsCallable(
      'runDiscoverySource',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>({
      'sourceId': sourceId,
    });
    return response.data;
  }

  /// Returns the number of new opportunities created by this run.
  Future<int> runSource(String sourceId) async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke(sourceId);
    } on FirebaseFunctionsException catch (e) {
      throw DiscoveryEngineException(_messageForFunctionsException(e));
    } catch (e) {
      throw DiscoveryEngineException('$e');
    }

    return (raw?['opportunitiesCreated'] as num?)?.toInt() ?? 0;
  }

  /// Every branch returns a lowercase-leading fragment, not a full sentence
  /// — same reasoning as `RecommendationEngineService`'s equivalent (avoids
  /// doubling up with the caller's own prefix).
  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the source was not found.';
      case 'failed-precondition':
        return e.message ?? 'this source cannot be run.';
      case 'unimplemented':
        return e.message ??
            'this source type is not yet automated — use manual entry instead.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
