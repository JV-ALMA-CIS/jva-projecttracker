import 'package:cloud_functions/cloud_functions.dart';

/// Result of one `backfillSourceUrlVerification` call — see
/// `functions/backfillSourceUrlVerification.js`.
class SourceUrlVerificationResult {
  const SourceUrlVerificationResult({
    required this.scanned,
    required this.checked,
    required this.hasMore,
    required this.lastId,
  });

  final int scanned;
  final int checked;
  final bool hasMore;
  final String? lastId;
}

class SourceUrlVerificationException implements Exception {
  SourceUrlVerificationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Admin-only maintenance action: re-checks every opportunity's
/// `sourceUrl` for reachability via `backfillSourceUrlVerification`, paging
/// through the collection with `startAfterId` until the server reports
/// `hasMore: false`.
class SourceUrlVerificationService {
  SourceUrlVerificationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<SourceUrlVerificationResult> runOnce({String? startAfterId}) async {
    try {
      final callable = _functions.httpsCallable(
        'backfillSourceUrlVerification',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 320)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'startAfterId': ?startAfterId,
      });
      return SourceUrlVerificationResult(
        scanned: result.data['scanned'] as int? ?? 0,
        checked: result.data['checked'] as int? ?? 0,
        hasMore: result.data['hasMore'] as bool? ?? false,
        lastId: result.data['lastId'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw SourceUrlVerificationException(
        e.message ?? 'Source URL verification failed',
      );
    }
  }

  /// Repeats [runOnce] until the server reports no more documents, returning
  /// the total number of source URLs actually checked across all calls.
  Future<int> runToCompletion() async {
    var totalChecked = 0;
    String? startAfterId;
    while (true) {
      final result = await runOnce(startAfterId: startAfterId);
      totalChecked += result.checked;
      if (!result.hasMore) break;
      startAfterId = result.lastId;
    }
    return totalChecked;
  }
}
