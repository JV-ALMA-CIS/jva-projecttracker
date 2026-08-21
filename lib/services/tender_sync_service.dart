import 'package:cloud_functions/cloud_functions.dart';

/// Thrown when a sync run fails, wrapping the underlying [FirebaseFunctionsException]
/// message so screens don't need to know about Cloud Functions error codes.
class TenderSyncException implements Exception {
  TenderSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Triggers a `TenderSource` sync by calling the `runTenderSourceSync`
/// callable. All connector dispatch, dedup, and `tenderSyncRuns`
/// bookkeeping happens server-side (see functions/tenderSourceSync.js) —
/// this service is a thin, testable wrapper around that one callable.
class TenderSyncService {
  TenderSyncService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Runs [sourceId] now. Returns the number of opportunities created.
  /// Throws [TenderSyncException] on failure (unautomated method, connector
  /// error, etc.) — the corresponding `tenderSyncRuns` document is always
  /// written server-side before this throws, so the attempt is never lost
  /// from Discovery/Sync History even on failure.
  Future<int> runSource(String sourceId) async {
    try {
      final callable = _functions.httpsCallable(
        'runTenderSourceSync',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'sourceId': sourceId,
        'trigger': 'manual',
      });
      return result.data['opportunitiesCreated'] as int? ?? 0;
    } on FirebaseFunctionsException catch (e) {
      throw TenderSyncException(e.message ?? 'Sync failed');
    }
  }

  /// Queues every enabled, non-manual `TenderSource` to run now, via the
  /// `runAllTenderSourcesNow` callable — the bulk counterpart to
  /// [runSource]. With 30+ sources configured, clicking "Run now" on each
  /// one individually isn't workable, so this exists as the one-click
  /// alternative on the Tender Sources screen. Admin-gated server-side.
  ///
  /// Returns as soon as the batch is queued (a few seconds), NOT once every
  /// source has finished — the actual syncs continue running server-side
  /// in the background after this returns (see the callable's doc comment
  /// in functions/tenderSourceSync.js for why: 25 sources' worth of real
  /// Gemini calls routinely takes well past what a callable can wait on).
  /// Progress shows up live without polling this call: each source's
  /// status updates as `tenderSourcesStreamProvider` refreshes, and every
  /// attempt lands in Sync History.
  Future<int> runAllSourcesNow() async {
    try {
      final callable = _functions.httpsCallable(
        'runAllTenderSourcesNow',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call<Map<String, dynamic>>();
      return result.data['queued'] as int? ?? 0;
    } on FirebaseFunctionsException catch (e) {
      throw TenderSyncException(e.message ?? 'Sync failed');
    }
  }
}
