import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';

void main() {
  final now = DateTime.utc(2024, 6, 1);

  Map<String, dynamic> baseMap({
    required Object candidatesFound,
    required Object opportunitiesCreated,
    required Object duplicatesSkipped,
  }) {
    return {
      'sourceId': 'src-1',
      'sourceName': 'Tenders Kenya (PPIP)',
      'discoveryMethod': 'api',
      'status': 'completed',
      'trigger': 'manual',
      'startedAt': Timestamp.fromDate(now),
      'candidatesFound': candidatesFound,
      'opportunitiesCreated': opportunitiesCreated,
      'duplicatesSkipped': duplicatesSkipped,
    };
  }

  // Regression coverage for the bug that made the Discovery Engine hang
  // indefinitely — see test/models/tender_source_model_test.dart's group
  // doc comment for the full explanation. `tenderSyncRuns` is written by
  // the same Cloud Functions path and is subject to the identical risk.
  for (final shape in ['int', 'double']) {
    test(
      'parses candidatesFound/opportunitiesCreated/duplicatesSkipped correctly when Firestore returns $shape values',
      () {
        Object asShape(num n) => shape == 'double' ? n.toDouble() : n.toInt();

        final run = TenderSyncRun.fromMap(
          'run-1',
          baseMap(
            candidatesFound: asShape(8),
            opportunitiesCreated: asShape(5),
            duplicatesSkipped: asShape(3),
          ),
        );

        expect(run.candidatesFound, 8);
        expect(run.opportunitiesCreated, 5);
        expect(run.duplicatesSkipped, 3);
      },
    );
  }

  test('defaults numeric fields to 0 when absent', () {
    final map = {
      'sourceId': 'src-1',
      'sourceName': 'Tenders Kenya (PPIP)',
      'discoveryMethod': 'api',
      'status': 'running',
      'trigger': 'scheduled',
      'startedAt': Timestamp.fromDate(now),
    };

    final run = TenderSyncRun.fromMap('run-1', map);

    expect(run.candidatesFound, 0);
    expect(run.opportunitiesCreated, 0);
    expect(run.duplicatesSkipped, 0);
  });
}
