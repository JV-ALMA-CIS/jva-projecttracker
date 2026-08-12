import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/recommendation_engine_service.dart';

void main() {
  test(
    'generateRecommendations returns the created count on a valid response',
    () async {
      final service = RecommendationEngineService(
        invokeOverride: () async => {'created': 3},
      );

      final created = await service.generateRecommendations();

      expect(created, 3);
    },
  );

  test('generateRecommendations returns 0 when created is missing', () async {
    final service = RecommendationEngineService(invokeOverride: () async => {});

    final created = await service.generateRecommendations();

    expect(created, 0);
  });

  test(
    'returns 0 when the response is null (a batch of zero is not a failure)',
    () async {
      final service = RecommendationEngineService(
        invokeOverride: () async => null,
      );

      final created = await service.generateRecommendations();

      expect(created, 0);
    },
  );

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as RecommendationEngineException',
    () async {
      final service = RecommendationEngineService(
        invokeOverride: () async => throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.generateRecommendations(),
        throwsA(
          isA<RecommendationEngineException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
