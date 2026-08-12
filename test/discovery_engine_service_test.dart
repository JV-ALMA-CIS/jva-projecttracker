import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/discovery_engine_service.dart';

void main() {
  test('runSource returns the created count on a valid response', () async {
    final service = DiscoveryEngineService(
      invokeOverride: ({required sourceId}) async => {
        'opportunitiesCreated': 4,
      },
    );

    final created = await service.runSource('source-1');

    expect(created, 4);
  });

  test(
    'runSource forwards the requested sourceId to the invoke callback',
    () async {
      String? received;
      final service = DiscoveryEngineService(
        invokeOverride: ({required sourceId}) async {
          received = sourceId;
          return {'opportunitiesCreated': 0};
        },
      );

      await service.runSource('source-42');

      expect(received, 'source-42');
    },
  );

  test('runSource returns 0 when opportunitiesCreated is missing', () async {
    final service = DiscoveryEngineService(
      invokeOverride: ({required sourceId}) async => {},
    );

    final created = await service.runSource('source-1');

    expect(created, 0);
  });

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as DiscoveryEngineException',
    () async {
      final service = DiscoveryEngineService(
        invokeOverride: ({required sourceId}) async =>
            throw Exception('network unreachable'),
      );

      expect(
        () => service.runSource('source-1'),
        throwsA(
          isA<DiscoveryEngineException>().having(
            (e) => e.toString(),
            'message',
            contains('network unreachable'),
          ),
        ),
      );
    },
  );
}
