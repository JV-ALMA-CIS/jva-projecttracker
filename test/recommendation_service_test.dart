import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late RecommendationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = RecommendationService(firestore: firestore);
  });

  Recommendation buildRecommendation({
    required DateTime generatedAt,
    String title = 'Fast-track the Rural Water Tender',
    RecommendationStatus status = RecommendationStatus.active,
  }) {
    return Recommendation(
      id: '',
      title: title,
      reasoning: 'Strong strategic fit and an approaching deadline.',
      status: status,
      generatedAt: generatedAt,
      createdAt: generatedAt,
      updatedAt: generatedAt,
    );
  }

  test('create writes a recommendation that watchAll then returns', () async {
    await service.create(
      buildRecommendation(generatedAt: DateTime.utc(2024, 8, 1)),
    );

    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.title, 'Fast-track the Rural Water Tender');
    expect(all.single.status, RecommendationStatus.active);
  });

  test(
    'watchAll orders recommendations most-recently-generated-first',
    () async {
      await service.create(
        buildRecommendation(
          generatedAt: DateTime.utc(2024, 1, 1),
          title: 'Older',
        ),
      );
      await service.create(
        buildRecommendation(
          generatedAt: DateTime.utc(2024, 6, 1),
          title: 'Newer',
        ),
      );

      final all = await service.watchAll().first;
      expect(all.map((r) => r.title), ['Newer', 'Older']);
    },
  );

  test('dismiss updates status to dismissed', () async {
    final id = await service.create(
      buildRecommendation(generatedAt: DateTime.utc(2024, 8, 1)),
    );

    await service.dismiss(id);

    final all = await service.watchAll().first;
    expect(all.single.status, RecommendationStatus.dismissed);
  });

  test('markActioned updates status to actioned', () async {
    final id = await service.create(
      buildRecommendation(generatedAt: DateTime.utc(2024, 8, 1)),
    );

    await service.markActioned(id);

    final all = await service.watchAll().first;
    expect(all.single.status, RecommendationStatus.actioned);
  });
}
