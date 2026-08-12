import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

/// Result of a connection test — deliberately not an exception-based API
/// like [TenderSyncService.runSource]. A failed test is an expected,
/// common outcome the admin form should display inline (see [ok]), not
/// something that should look like a crash.
class TenderConnectionTestResult {
  const TenderConnectionTestResult({
    required this.ok,
    required this.message,
    this.sampleCount,
  });

  final bool ok;
  final String message;
  final int? sampleCount;
}

/// Wraps the `testTenderSourceConnection` callable. Never writes any
/// opportunities — see functions/testTenderSourceConnection.js.
class TenderConnectionTestService {
  TenderConnectionTestService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Tests an already-saved source by id.
  Future<TenderConnectionTestResult> testSaved(String sourceId) {
    return _call({'sourceId': sourceId});
  }

  /// Tests a not-yet-saved draft — used by the Add Source dialog's
  /// "Test connection" button before the admin commits to saving it.
  Future<TenderConnectionTestResult> testDraft(TenderSource draft) {
    return _call({
      'draft': {
        'discoveryMethod': draft.discoveryMethod.name,
        'connectorConfig': draft.connectorConfig,
        'authConfig': draft.authConfig,
        'category': draft.category.name,
        'name': draft.name,
        'organization': draft.organization,
      },
    });
  }

  Future<TenderConnectionTestResult> _call(Map<String, dynamic> data) async {
    try {
      final callable = _functions.httpsCallable('testTenderSourceConnection');
      final result = await callable.call<Map<String, dynamic>>(data);
      return TenderConnectionTestResult(
        ok: result.data['ok'] as bool? ?? false,
        message: result.data['message'] as String? ?? '',
        sampleCount: result.data['sampleCount'] as int?,
      );
    } on FirebaseFunctionsException catch (e) {
      return TenderConnectionTestResult(
        ok: false,
        message: e.message ?? 'Connection test failed',
      );
    }
  }
}
