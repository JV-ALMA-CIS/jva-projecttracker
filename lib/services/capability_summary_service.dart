import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `CapabilitySummaryService.generateSummary`
/// can hit — mirrors `ProductSummaryException`/`ServiceSummaryException`
/// exactly.
class CapabilitySummaryException implements Exception {
  const CapabilitySummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateCapabilitySummary` Cloud Function, which writes the
/// "AI summary of application" directly onto the `capabilities` document.
/// Mirrors `ProductSummaryService`/`ServiceSummaryService` exactly.
class CapabilitySummaryService {
  CapabilitySummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String capabilityId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String capabilityId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String capabilityId) async {
    final callable = _functions.httpsCallable(
      'generateCapabilitySummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'capabilityId': capabilityId});
  }

  Future<void> generateSummary({required String capabilityId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(capabilityId: capabilityId);
      } else {
        await _callCloudFunction(capabilityId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw CapabilitySummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw CapabilitySummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the capability was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
