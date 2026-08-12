import 'package:cloud_functions/cloud_functions.dart';

/// Result of a seed run — see `functions/seedCompanyBusinessUnits.js`.
class BusinessUnitSeedResult {
  const BusinessUnitSeedResult({
    required this.created,
    required this.skipped,
    required this.total,
  });

  final int created;
  final int skipped;
  final int total;
}

class BusinessUnitSeedException implements Exception {
  BusinessUnitSeedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Admin-only action: ensures the canonical JV ALMA CIS Business Unit list
/// (Construction, Facility Management, Agribusiness, Information
/// Technology, Human Resources) exists in `businessUnits` — the
/// prerequisite for `classifyOpportunity` and
/// `OpportunityBusinessUnitBackfillService` to have anything real to match
/// against. Idempotent: re-running only fills in whatever's still missing,
/// matched by both seedKey and name — see
/// `functions/seedCompanyBusinessUnits.js`.
class BusinessUnitSeedService {
  BusinessUnitSeedService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<BusinessUnitSeedResult> seedCanonicalBusinessUnits() async {
    try {
      final callable = _functions.httpsCallable('seedCompanyBusinessUnits');
      final result = await callable.call<Map<String, dynamic>>();
      return BusinessUnitSeedResult(
        created: result.data['created'] as int? ?? 0,
        skipped: result.data['skipped'] as int? ?? 0,
        total: result.data['total'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw BusinessUnitSeedException(e.message ?? 'Seeding failed');
    }
  }
}
