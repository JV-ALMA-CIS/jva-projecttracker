import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/services/strategic_review_parser.dart';

/// Thrown for every failure mode `StrategicReviewService.generateReview` can
/// hit — API failures, timeouts, invalid/empty model output — so the UI
/// layer only ever needs to catch one exception type and show its message.
/// Mirrors `MatchAnalysisException` from Milestone 3.4 exactly.
class StrategicReviewException implements Exception {
  const StrategicReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateStrategicReview` Cloud Function, which runs Gemini
/// against the opportunity + its existing classification/match-analysis
/// fields + the Company Knowledge Graph (see `functions/index.js`) and
/// writes the strategic-review fields directly to Firestore — the live
/// `opportunityByIdProvider` stream picks that up on its own. The parsed-
/// and-validated result is also returned here so the calling screen can
/// render it immediately, without waiting for the stream. Mirrors
/// `MatchAnalysisService` from Milestone 3.4 exactly — see ADR-005 for why
/// this shape (lazily-resolved `FirebaseFunctions`, an `invokeOverride` test
/// seam, one exception type) is now used by every Gemini-backed service in
/// this app.
class StrategicReviewService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses (including malformed ones)
  /// with no Firebase involved at all. Production code never sets it.
  StrategicReviewService({
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>?> Function(String opportunityId)?
    invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<Map<String, dynamic>?> Function(String opportunityId)?
  _invokeOverride;

  // Resolved lazily — constructing this with only invokeOverride set (the
  // shape every test in this app uses) must not require Firebase Core to
  // be initialized.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _invoke(String opportunityId) {
    final override = _invokeOverride;
    if (override != null) return override(opportunityId);
    return _callCloudFunction(opportunityId);
  }

  Future<Map<String, dynamic>?> _callCloudFunction(String opportunityId) async {
    final callable = _functions.httpsCallable(
      'generateStrategicReview',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>({
      'opportunityId': opportunityId,
    });
    return response.data;
  }

  Future<StrategicReviewResult> generateReview(String opportunityId) async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke(opportunityId);
    } on FirebaseFunctionsException catch (e) {
      throw StrategicReviewException(_messageForFunctionsException(e));
    } catch (e) {
      // Callers (AppStrings.strategicReviewFailed) already add a
      // "Strategic review failed:" framing — this message stays just the
      // underlying fact, so the two don't stack into a doubled-up sentence.
      throw StrategicReviewException('$e');
    }

    final result = parseStrategicReviewResponse(raw);
    if (result == null) {
      throw const StrategicReviewException('the response was unusable.');
    }
    return result;
  }

  /// Every branch returns a lowercase-leading fragment, not a full sentence
  /// — see the comment above on why (avoids doubling up with the caller's
  /// own "Strategic review failed:" prefix).
  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the opportunity was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
