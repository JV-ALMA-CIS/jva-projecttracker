import 'package:cloud_functions/cloud_functions.dart';

/// Result of a seed run — how many of the 30 production sources were
/// newly created vs. already existed (idempotent — safe to call again).
class TenderSourceSeedResult {
  const TenderSourceSeedResult({
    required this.created,
    required this.skipped,
    required this.total,
  });

  final int created;
  final int skipped;
  final int total;
}

class TenderSourceSeedException implements Exception {
  TenderSourceSeedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One-shot admin action: populates `tenderSources` with the 30 real
/// government/donor/UN/NGO procurement organizations, each using the
/// proven `api` + `aiSearch` connector mode (no per-site scraper
/// knowledge required — see functions/seedTenderSources.js). Idempotent:
/// re-running only fills in any missing entries.
class TenderSourceSeedService {
  TenderSourceSeedService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<TenderSourceSeedResult> seedProductionSources() async {
    try {
      final callable = _functions.httpsCallable('seedProductionTenderSources');
      final result = await callable.call<Map<String, dynamic>>();
      return TenderSourceSeedResult(
        created: result.data['created'] as int? ?? 0,
        skipped: result.data['skipped'] as int? ?? 0,
        total: result.data['total'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw TenderSourceSeedException(e.message ?? 'Seeding failed');
    }
  }
}
