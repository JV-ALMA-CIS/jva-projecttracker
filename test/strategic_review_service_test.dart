import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/strategic_review_service.dart';

void main() {
  test('generateReview returns a parsed result on a valid response', () async {
    final service = StrategicReviewService(
      invokeOverride: (opportunityId) async => {
        'executiveRecommendation': 'pursue',
        'executiveSummary': 'Strong match, pursue.',
        'strategicReviewBusinessUnitIds': ['unit-1'],
        'strategicStrengths': ['Relevant past experience'],
      },
    );

    final result = await service.generateReview('opportunity-1');

    expect(result.executiveSummary, 'Strong match, pursue.');
    expect(result.strategicReviewBusinessUnitIds, ['unit-1']);
    expect(result.strategicStrengths, ['Relevant past experience']);
  });

  test('forwards the requested opportunityId to the invoke callback', () async {
    String? seenId;
    final service = StrategicReviewService(
      invokeOverride: (opportunityId) async {
        seenId = opportunityId;
        return {'executiveSummary': 'Ok.'};
      },
    );

    await service.generateReview('opportunity-42');

    expect(seenId, 'opportunity-42');
  });

  test(
    'throws StrategicReviewException when the response is unusable (no live API call made)',
    () async {
      final service = StrategicReviewService(
        invokeOverride: (opportunityId) async => {
          'executiveRecommendation': 'pursue',
        },
      );

      expect(
        () => service.generateReview('opportunity-1'),
        throwsA(isA<StrategicReviewException>()),
      );
    },
  );

  test('throws StrategicReviewException when the response is null', () async {
    final service = StrategicReviewService(
      invokeOverride: (opportunityId) async => null,
    );

    expect(
      () => service.generateReview('opportunity-1'),
      throwsA(isA<StrategicReviewException>()),
    );
  });

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as StrategicReviewException',
    () async {
      final service = StrategicReviewService(
        invokeOverride: (opportunityId) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.generateReview('opportunity-1'),
        throwsA(
          isA<StrategicReviewException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
