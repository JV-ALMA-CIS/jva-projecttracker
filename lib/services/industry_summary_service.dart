import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `IndustrySummaryService.generateSummary`
/// can hit — mirrors `TechnologySummaryException`/`CapabilitySummaryException`
/// exactly.
class IndustrySummaryException implements Exception {
  const IndustrySummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateIndustrySummary` Cloud Function, which writes the "AI
/// summary of application" directly onto the `industries` document. Mirrors
/// `TechnologySummaryService`/`CapabilitySummaryService` exactly.
class IndustrySummaryService {
  IndustrySummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String industryId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String industryId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String industryId) async {
    final callable = _functions.httpsCallable(
      'generateIndustrySummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'industryId': industryId});
  }

  Future<void> generateSummary({required String industryId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(industryId: industryId);
      } else {
        await _callCloudFunction(industryId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw IndustrySummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw IndustrySummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the industry was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
