import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

void main() {
  test('DiscoveryRun round-trips from Firestore maps', () {
    final startedAt = DateTime.utc(2024, 8, 1, 8);
    final completedAt = DateTime.utc(2024, 8, 1, 8, 2);

    final run = DiscoveryRun(
      id: 'run-1',
      sourceId: 'source-1',
      sourceName: 'World Bank tenders',
      sourceType: DiscoverySourceType.developmentOrganization,
      status: DiscoveryRunStatus.completed,
      trigger: DiscoveryRunTrigger.scheduled,
      candidatesFound: 8,
      opportunitiesCreated: 5,
      duplicatesSkipped: 3,
      startedAt: startedAt,
      completedAt: completedAt,
    );

    final restored = DiscoveryRun.fromMap(run.id, run.toMap());

    expect(restored.sourceId, run.sourceId);
    expect(restored.sourceName, run.sourceName);
    expect(restored.sourceType, DiscoverySourceType.developmentOrganization);
    expect(restored.status, DiscoveryRunStatus.completed);
    expect(restored.trigger, DiscoveryRunTrigger.scheduled);
    expect(restored.candidatesFound, 8);
    expect(restored.opportunitiesCreated, 5);
    expect(restored.duplicatesSkipped, 3);
    expect(restored.errorMessage, isNull);
    expect(restored.startedAt.toUtc(), startedAt.toUtc());
    expect(restored.completedAt?.toUtc(), completedAt.toUtc());
  });

  test('DiscoveryRun round-trips a failed run with an error message', () {
    final startedAt = DateTime.utc(2024, 8, 1);

    final run = DiscoveryRun(
      id: 'run-2',
      sourceId: 'source-2',
      sourceName: 'RSS feed',
      sourceType: DiscoverySourceType.rss,
      status: DiscoveryRunStatus.failed,
      errorMessage: 'Source type "rss" is not yet automated.',
      startedAt: startedAt,
    );

    final restored = DiscoveryRun.fromMap(run.id, run.toMap());

    expect(restored.status, DiscoveryRunStatus.failed);
    expect(restored.errorMessage, 'Source type "rss" is not yet automated.');
    expect(restored.completedAt, isNull);
  });

  test(
    'unknown status/trigger strings fall back sanely rather than throwing',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = DiscoveryRun.fromMap('run-3', {
        'sourceId': 'source-3',
        'sourceName': 'Something',
        'sourceType': 'manual',
        'status': 'not-a-real-status',
        'trigger': 'not-a-real-trigger',
        'startedAt': Timestamp.fromDate(now),
      });

      expect(restored.status, DiscoveryRunStatus.failed);
      expect(restored.trigger, DiscoveryRunTrigger.manual);
    },
  );
}
