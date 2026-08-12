import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode
/// `KnowledgeArticleSummaryService.generateSummary` can hit — mirrors
/// `ExperienceSummaryException`/`IndustrySummaryException` exactly.
class KnowledgeArticleSummaryException implements Exception {
  const KnowledgeArticleSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateKnowledgeArticleSummary` Cloud Function, which writes
/// a short "practical relevance" narrative directly onto the
/// `knowledgeBase` document. Mirrors `ExperienceSummaryService`/
/// `IndustrySummaryService` exactly.
class KnowledgeArticleSummaryService {
  KnowledgeArticleSummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String articleId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String articleId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String articleId) async {
    final callable = _functions.httpsCallable(
      'generateKnowledgeArticleSummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'articleId': articleId});
  }

  Future<void> generateSummary({required String articleId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(articleId: articleId);
      } else {
        await _callCloudFunction(articleId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw KnowledgeArticleSummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw KnowledgeArticleSummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the article was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
