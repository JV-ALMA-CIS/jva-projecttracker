import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `ServiceSummaryService.generateSummary`
/// can hit — mirrors `ProductSummaryException`/`BusinessUnitSummaryException`
/// exactly.
class ServiceSummaryException implements Exception {
  const ServiceSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateServiceSummary` Cloud Function, which writes the "AI
/// summary of positioning" directly onto the `services` document. Mirrors
/// `ProductSummaryService` exactly.
class ServiceSummaryService {
  ServiceSummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String serviceId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String serviceId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String serviceId) async {
    final callable = _functions.httpsCallable(
      'generateServiceSummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'serviceId': serviceId});
  }

  Future<void> generateSummary({required String serviceId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(serviceId: serviceId);
      } else {
        await _callCloudFunction(serviceId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServiceSummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw ServiceSummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the service was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
