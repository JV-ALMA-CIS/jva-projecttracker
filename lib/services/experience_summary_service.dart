import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `ExperienceSummaryService.generateSummary`
/// can hit — mirrors `IndustrySummaryException`/`TechnologySummaryException`
/// exactly.
class ExperienceSummaryException implements Exception {
  const ExperienceSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateExperienceSummary` Cloud Function, which writes a
/// polished executive narrative directly onto the `experiences` document.
/// Mirrors `IndustrySummaryService`/`TechnologySummaryService` exactly.
class ExperienceSummaryService {
  ExperienceSummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String experienceId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String experienceId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String experienceId) async {
    final callable = _functions.httpsCallable(
      'generateExperienceSummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'experienceId': experienceId});
  }

  Future<void> generateSummary({required String experienceId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(experienceId: experienceId);
      } else {
        await _callCloudFunction(experienceId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw ExperienceSummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw ExperienceSummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the experience was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
