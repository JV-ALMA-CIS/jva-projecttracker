import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `BusinessUnitSummaryService.generateSummary`
/// can hit — mirrors `ProjectExtractionException` exactly.
class BusinessUnitSummaryException implements Exception {
  const BusinessUnitSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateBusinessUnitSummary` Cloud Function, which writes the
/// "AI summary of expertise" directly onto the `businessUnits` document.
/// Callers watch the business unit's own Firestore stream for the result.
class BusinessUnitSummaryService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved.
  BusinessUnitSummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String businessUnitId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String businessUnitId})?
  _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String businessUnitId) async {
    final callable = _functions.httpsCallable(
      'generateBusinessUnitSummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({
      'businessUnitId': businessUnitId,
    });
  }

  Future<void> generateSummary({required String businessUnitId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(businessUnitId: businessUnitId);
      } else {
        await _callCloudFunction(businessUnitId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw BusinessUnitSummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw BusinessUnitSummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the business unit was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
