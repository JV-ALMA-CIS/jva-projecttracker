import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `TechnologySummaryService.generateSummary`
/// can hit — mirrors `CapabilitySummaryException`/`ProductSummaryException`
/// exactly.
class TechnologySummaryException implements Exception {
  const TechnologySummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateTechnologySummary` Cloud Function, which writes the
/// "AI summary of application" directly onto the `technologies` document.
/// Mirrors `CapabilitySummaryService`/`ProductSummaryService` exactly.
class TechnologySummaryService {
  TechnologySummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String technologyId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String technologyId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String technologyId) async {
    final callable = _functions.httpsCallable(
      'generateTechnologySummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'technologyId': technologyId});
  }

  Future<void> generateSummary({required String technologyId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(technologyId: technologyId);
      } else {
        await _callCloudFunction(technologyId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw TechnologySummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw TechnologySummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the technology was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
