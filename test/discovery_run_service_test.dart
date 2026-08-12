import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/discovery_run_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DiscoveryRunService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DiscoveryRunService(firestore: firestore);
  });

  DiscoveryRun buildRun({
    required String sourceId,
    required DateTime startedAt,
    DiscoveryRunStatus status = DiscoveryRunStatus.completed,
  }) {
    return DiscoveryRun(
      id: '',
      sourceId: sourceId,
      sourceName: 'Source $sourceId',
      sourceType: DiscoverySourceType.governmentProcurement,
      status: status,
      startedAt: startedAt,
    );
  }

  test('create writes a run that watchAll then returns', () async {
    await service.create(
      buildRun(sourceId: 'source-1', startedAt: DateTime.utc(2024, 8, 1)),
    );

    final runs = await service.watchAll().first;
    expect(runs, hasLength(1));
    expect(runs.single.sourceId, 'source-1');
  });

  test('watchAll orders runs most-recent-first', () async {
    await service.create(
      buildRun(sourceId: 'source-1', startedAt: DateTime.utc(2024, 1, 1)),
    );
    await service.create(
      buildRun(sourceId: 'source-1', startedAt: DateTime.utc(2024, 6, 1)),
    );

    final runs = await service.watchAll().first;
    expect(runs, hasLength(2));
    expect(runs.first.startedAt.month, 6);
    expect(runs.last.startedAt.month, 1);
  });

  test(
    'watchBySource only returns runs for the requested source, most-recent-first',
    () async {
      await service.create(
        buildRun(sourceId: 'source-1', startedAt: DateTime.utc(2024, 1, 1)),
      );
      await service.create(
        buildRun(sourceId: 'source-2', startedAt: DateTime.utc(2024, 2, 1)),
      );
      await service.create(
        buildRun(sourceId: 'source-1', startedAt: DateTime.utc(2024, 6, 1)),
      );

      final runs = await service.watchBySource('source-1').first;
      expect(runs, hasLength(2));
      expect(runs.every((r) => r.sourceId == 'source-1'), isTrue);
      expect(runs.first.startedAt.month, 6);
      expect(runs.last.startedAt.month, 1);
    },
  );
}
