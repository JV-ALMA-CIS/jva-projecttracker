import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/services/match_analysis_parser.dart';

/// Thrown for every failure mode `MatchAnalysisService.analyzeMatch` can
/// hit — API failures, timeouts, invalid/empty model output — so the UI
/// layer only ever needs to catch one exception type and show its message.
/// Mirrors `AIClassificationException` from Milestone 3.3 exactly.
class MatchAnalysisException implements Exception {
  const MatchAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `analyzeOpportunityMatch` Cloud Function, which runs Gemini
/// against the opportunity + Company Knowledge Graph (see
/// `functions/index.js`) and writes the match-analysis fields directly to
/// Firestore — the live `opportunityByIdProvider` stream picks that up on
/// its own. The parsed-and-validated result is also returned here so the
/// calling screen can render it immediately, without waiting for the
/// stream. Mirrors `AIClassificationService` from Milestone 3.3 exactly —
/// see ADR-003/ADR-004 for why this shape (lazily-resolved
/// `FirebaseFunctions`, an `invokeOverride` test seam, one exception type)
/// is now used by every Gemini-backed service in this app.
class MatchAnalysisService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses (including malformed ones)
  /// with no Firebase involved at all. Production code never sets it.
  MatchAnalysisService({
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
      'analyzeOpportunityMatch',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>({
      'opportunityId': opportunityId,
    });
    return response.data;
  }

  Future<MatchAnalysisResult> analyzeMatch(String opportunityId) async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke(opportunityId);
    } on FirebaseFunctionsException catch (e) {
      throw MatchAnalysisException(_messageForFunctionsException(e));
    } catch (e) {
      // Callers (AppStrings.matchAnalysisFailed) already add a
      // "Match analysis failed:" framing — this message stays just the
      // underlying fact, so the two don't stack into a doubled-up sentence.
      throw MatchAnalysisException('$e');
    }

    final result = parseMatchAnalysisResponse(raw);
    if (result == null) {
      throw const MatchAnalysisException('the response was unusable.');
    }
    return result;
  }

  /// Every branch returns a lowercase-leading fragment, not a full sentence
  /// — see the comment above on why (avoids doubling up with the caller's
  /// own "Match analysis failed:" prefix).
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
