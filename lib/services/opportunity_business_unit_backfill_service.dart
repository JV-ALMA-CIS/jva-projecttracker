import 'package:cloud_functions/cloud_functions.dart';

/// Result of a backfill run — see `functions/backfillOpportunityBusinessUnits.js`.
class OpportunityBusinessUnitBackfillResult {
  const OpportunityBusinessUnitBackfillResult({
    required this.processed,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int processed;
  final int updated;
  final int skipped;
  final int errors;
}

class OpportunityBusinessUnitBackfillException implements Exception {
  OpportunityBusinessUnitBackfillException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Admin-only bulk action: assigns `Opportunity.businessUnitIds` for
/// opportunities that don't have one yet, by asking Gemini to pick from the
/// real `businessUnits` catalog (never inventing a new one) — see
/// `functions/backfillOpportunityBusinessUnits.js`. Idempotent by default
/// (only touches opportunities with empty `businessUnitIds`); batched
/// server-side, so a large backlog may need more than one tap.
class OpportunityBusinessUnitBackfillService {
  OpportunityBusinessUnitBackfillService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<OpportunityBusinessUnitBackfillResult> run({
    bool force = false,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'backfillOpportunityBusinessUnits',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'force': force,
      });
      return OpportunityBusinessUnitBackfillResult(
        processed: result.data['processed'] as int? ?? 0,
        updated: result.data['updated'] as int? ?? 0,
        skipped: result.data['skipped'] as int? ?? 0,
        errors: result.data['errors'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw OpportunityBusinessUnitBackfillException(
        e.message ?? 'Business unit backfill failed',
      );
    }
  }
}
