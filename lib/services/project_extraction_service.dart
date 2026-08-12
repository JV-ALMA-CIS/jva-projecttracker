import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `ProjectExtractionService.extract` can
/// hit — mirrors `SubmissionReviewException`/`ProposalGenerationException`
/// exactly, so the UI layer only ever needs to catch one exception type.
class ProjectExtractionException implements Exception {
  const ProjectExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `extractProjectDocumentKnowledge` Cloud Function, which reads
/// an uploaded document's file from Firebase Storage, sends it to Gemini
/// alongside the Company Knowledge Graph, and writes the extracted
/// `aiExtracted*` fields directly onto the `documents` document — mirrors
/// `SubmissionReviewService` exactly. Callers watch the document's own
/// Firestore stream for the result rather than this call's return value
/// (same convention as every other AI-writes-then-client-watches feature
/// in this app).
class ProjectExtractionService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved.
  ProjectExtractionService({
    FirebaseFunctions? functions,
    Future<void> Function({required String documentId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String documentId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String documentId) async {
    final callable = _functions.httpsCallable(
      'extractProjectDocumentKnowledge',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    await callable.call<Map<String, dynamic>>({'documentId': documentId});
  }

  Future<void> extract({required String documentId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(documentId: documentId);
      } else {
        await _callCloudFunction(documentId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw ProjectExtractionException(_messageForFunctionsException(e));
    } catch (e) {
      throw ProjectExtractionException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the document was not found.';
      case 'failed-precondition':
        // Covers both "no file uploaded yet" and "unsupported file type for
        // AI extraction" — the Cloud Function's message already
        // distinguishes the two, so surface it directly rather than a
        // fixed string that would be wrong for one of the cases.
        return e.message ?? 'the document has no uploaded file yet.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
