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
}
