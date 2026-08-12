import 'package:cloud_functions/cloud_functions.dart';
import 'package:jva_projecttracker/services/submission_review_parser.dart';

/// Thrown for every failure mode `SubmissionReviewService.generateReview`
/// can hit — mirrors `ProposalGenerationException`/`StrategicReviewException`
/// exactly, so the UI layer only ever needs to catch one exception type.
class SubmissionReviewException implements Exception {
  const SubmissionReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateSubmissionReview` Cloud Function, which reasons over
/// the opportunity's full AI chain plus every one of this proposal's own
/// section contents plus its Document Library readiness (see
/// `functions/index.js`), and writes the review directly onto the
/// `proposals` document. Mirrors `ProposalGenerationService` exactly — see
/// ADR-006 for why this shape is used by every Gemini-backed service here.
class SubmissionReviewService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved.
  SubmissionReviewService({
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>?> Function({required String proposalId})?
    invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<Map<String, dynamic>?> Function({required String proposalId})?
  _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _invoke(String proposalId) {
    final override = _invokeOverride;
    if (override != null) return override(proposalId: proposalId);
    return _callCloudFunction(proposalId);
  }

  Future<Map<String, dynamic>?> _callCloudFunction(String proposalId) async {
    final callable = _functions.httpsCallable(
      'generateSubmissionReview',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final response = await callable.call<Map<String, dynamic>>({
      'proposalId': proposalId,
    });
    return response.data;
  }

  Future<SubmissionReviewResult> generateReview({
    required String proposalId,
  }) async {
    Map<String, dynamic>? raw;
    try {
      raw = await _invoke(proposalId);
    } on FirebaseFunctionsException catch (e) {
      throw SubmissionReviewException(_messageForFunctionsException(e));
    } catch (e) {
      throw SubmissionReviewException('$e');
    }

    final result = parseSubmissionReviewResponse(raw);
    if (result == null) {
      throw const SubmissionReviewException('the response was unusable.');
    }
    return result;
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the proposal was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
