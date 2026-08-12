import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/ai_classification_service.dart';

void main() {
  test(
    'classifyOpportunity returns a parsed result on a valid response',
    () async {
      final service = AIClassificationService(
        invokeOverride: (opportunityId) async => {
          'classificationSummary': 'Strong match.',
          'industryIds': ['industry-1'],
          'confidenceScore': 88,
          'priority': 'high',
          'riskLevel': 'low',
          'estimatedComplexity': 'medium',
          'classificationStatus': 'classified',
          'aiReviewedAt': '2024-08-01T12:00:00.000Z',
        },
      );

      final result = await service.classifyOpportunity('opportunity-1');

      expect(result.classificationSummary, 'Strong match.');
      expect(result.industryIds, ['industry-1']);
      expect(result.confidenceScore, 88);
      expect(result.priority, OpportunityPriority.high);
      expect(result.riskLevel, RiskLevel.low);
      expect(result.estimatedComplexity, EstimatedComplexity.medium);
      expect(result.classificationStatus, ClassificationStatus.classified);
    },
  );

  test('forwards the requested opportunityId to the invoke callback', () async {
    String? seenId;
    final service = AIClassificationService(
      invokeOverride: (opportunityId) async {
        seenId = opportunityId;
        return {'classificationSummary': 'Ok.'};
      },
    );

    await service.classifyOpportunity('opportunity-42');

    expect(seenId, 'opportunity-42');
  });

  test(
    'throws AIClassificationException when the response is unusable (no live API call made)',
    () async {
      final service = AIClassificationService(
        invokeOverride: (opportunityId) async => {
          'industryIds': ['industry-1'],
        },
      );

      expect(
        () => service.classifyOpportunity('opportunity-1'),
        throwsA(isA<AIClassificationException>()),
      );
    },
  );

  test('throws AIClassificationException when the response is null', () async {
    final service = AIClassificationService(
      invokeOverride: (opportunityId) async => null,
    );

    expect(
      () => service.classifyOpportunity('opportunity-1'),
      throwsA(isA<AIClassificationException>()),
    );
  });

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as AIClassificationException',
    () async {
      final service = AIClassificationService(
        invokeOverride: (opportunityId) async =>
            throw Exception('network unreachable'),
      );

      expect(
        () => service.classifyOpportunity('opportunity-1'),
        throwsA(
          isA<AIClassificationException>().having(
            (e) => e.toString(),
            'message',
            contains('network unreachable'),
          ),
        ),
      );
    },
  );
}
