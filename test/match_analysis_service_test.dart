import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/match_analysis_service.dart';

void main() {
  test('analyzeMatch returns a parsed result on a valid response', () async {
    final service = MatchAnalysisService(
      invokeOverride: (opportunityId) async => {
        'overallMatchScore': 91,
        'businessUnitScore': 85,
        'strategicRecommendation': 'Strong match, pursue.',
        'recommendedProductIds': ['product-1'],
        'strengths': ['Relevant past experience'],
      },
    );

    final result = await service.analyzeMatch('opportunity-1');

    expect(result.overallMatchScore, 91);
    expect(result.businessUnitScore, 85);
    expect(result.strategicRecommendation, 'Strong match, pursue.');
    expect(result.recommendedProductIds, ['product-1']);
    expect(result.strengths, ['Relevant past experience']);
  });

  test('forwards the requested opportunityId to the invoke callback', () async {
    String? seenId;
    final service = MatchAnalysisService(
      invokeOverride: (opportunityId) async {
        seenId = opportunityId;
        return {'strategicRecommendation': 'Ok.'};
      },
    );

    await service.analyzeMatch('opportunity-42');

    expect(seenId, 'opportunity-42');
  });

  test(
    'throws MatchAnalysisException when the response is unusable (no live API call made)',
    () async {
      final service = MatchAnalysisService(
        invokeOverride: (opportunityId) async => {'overallMatchScore': 80},
      );

      expect(
        () => service.analyzeMatch('opportunity-1'),
        throwsA(isA<MatchAnalysisException>()),
      );
    },
  );

  test('throws MatchAnalysisException when the response is null', () async {
    final service = MatchAnalysisService(
      invokeOverride: (opportunityId) async => null,
    );

    expect(
      () => service.analyzeMatch('opportunity-1'),
      throwsA(isA<MatchAnalysisException>()),
    );
  });

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as MatchAnalysisException',
    () async {
      final service = MatchAnalysisService(
        invokeOverride: (opportunityId) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.analyzeMatch('opportunity-1'),
        throwsA(
          isA<MatchAnalysisException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
