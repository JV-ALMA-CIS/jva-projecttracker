import 'package:cloud_functions/cloud_functions.dart';

/// Thrown for every failure mode `ProductSummaryService.generateSummary`
/// can hit — mirrors `BusinessUnitSummaryException` exactly.
class ProductSummaryException implements Exception {
  const ProductSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the `generateProductSummary` Cloud Function, which writes the "AI
/// summary of positioning" directly onto the `products` document. Callers
/// watch the product's own Firestore stream for the result. Mirrors
/// `BusinessUnitSummaryService` exactly, one level down the Company
/// Intelligence graph.
class ProductSummaryService {
  /// [invokeOverride] replaces the actual Cloud Function call entirely —
  /// used by tests to supply canned responses with no Firebase involved.
  ProductSummaryService({
    FirebaseFunctions? functions,
    Future<void> Function({required String productId})? invokeOverride,
  }) : _functionsOverride = functions,
       // ignore: prefer_initializing_formals
       _invokeOverride = invokeOverride;

  final FirebaseFunctions? _functionsOverride;
  final Future<void> Function({required String productId})? _invokeOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> _callCloudFunction(String productId) async {
    final callable = _functions.httpsCallable(
      'generateProductSummary',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    await callable.call<Map<String, dynamic>>({'productId': productId});
  }

  Future<void> generateSummary({required String productId}) async {
    try {
      final override = _invokeOverride;
      if (override != null) {
        await override(productId: productId);
      } else {
        await _callCloudFunction(productId);
      }
    } on FirebaseFunctionsException catch (e) {
      throw ProductSummaryException(_messageForFunctionsException(e));
    } catch (e) {
      throw ProductSummaryException('$e');
    }
  }

  String _messageForFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'deadline-exceeded':
        return 'it timed out. Please try again.';
      case 'not-found':
        return 'the product was not found.';
      case 'invalid-argument':
        return 'the request was invalid.';
      default:
        return e.message ?? 'of an unknown error.';
    }
  }
}
