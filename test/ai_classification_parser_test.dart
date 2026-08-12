import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/ai_classification_parser.dart';

void main() {
  group('parseAIClassificationResponse — valid input', () {
    test('parses a fully-populated classification response', () {
      final result = parseAIClassificationResponse({
        'classificationSummary':
            'Strong match for our water infrastructure practice.',
        'industryIds': ['industry-1'],
        'technologyIds': ['tech-1', 'tech-2'],
        'businessUnitIds': ['unit-1'],
        'productIds': ['product-1'],
        'serviceIds': ['service-1'],
        'capabilityIds': ['cap-1'],
        'experienceIds': ['experience-1'],
        'knowledgeArticleIds': ['article-1'],
        'estimatedComplexity': 'high',
        'priority': 'high',
        'riskLevel': 'medium',
        'confidenceScore': 82,
        'classificationStatus': 'classified',
        'aiReviewedAt': '2024-08-01T12:00:00.000Z',
      });

      expect(result, isNotNull);
      expect(
        result!.classificationSummary,
        'Strong match for our water infrastructure practice.',
      );
      expect(result.industryIds, ['industry-1']);
      expect(result.technologyIds, ['tech-1', 'tech-2']);
      expect(result.businessUnitIds, ['unit-1']);
      expect(result.productIds, ['product-1']);
      expect(result.serviceIds, ['service-1']);
      expect(result.capabilityIds, ['cap-1']);
      expect(result.experienceIds, ['experience-1']);
      expect(result.knowledgeArticleIds, ['article-1']);
      expect(result.estimatedComplexity, EstimatedComplexity.high);
      expect(result.priority, OpportunityPriority.high);
      expect(result.riskLevel, RiskLevel.medium);
      expect(result.confidenceScore, 82);
      expect(result.classificationStatus, ClassificationStatus.classified);
      expect(result.aiReviewedAt, DateTime.parse('2024-08-01T12:00:00.000Z'));
    });

    test('defaults missing relationship/enum fields gracefully', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Thin description, low confidence match.',
      });

      expect(result, isNotNull);
      expect(result!.industryIds, isEmpty);
      expect(result.technologyIds, isEmpty);
      expect(result.businessUnitIds, isEmpty);
      expect(result.productIds, isEmpty);
      expect(result.serviceIds, isEmpty);
      expect(result.capabilityIds, isEmpty);
      expect(result.experienceIds, isEmpty);
      expect(result.knowledgeArticleIds, isEmpty);
      expect(result.estimatedComplexity, isNull);
      expect(result.priority, isNull);
      expect(result.riskLevel, isNull);
      expect(result.confidenceScore, isNull);
      // classificationStatus always resolves to something usable — an
      // absent/invalid value means "AI couldn't confidently classify this".
      expect(result.classificationStatus, ClassificationStatus.needsReview);
      expect(result.aiReviewedAt, isNull);
    });
  });

  group('parseAIClassificationResponse — malformed/partial input', () {
    test('returns null for a null payload', () {
      expect(parseAIClassificationResponse(null), isNull);
    });

    test('returns null when classificationSummary is missing', () {
      final result = parseAIClassificationResponse({
        'industryIds': ['industry-1'],
      });
      expect(result, isNull);
    });

    test('returns null when classificationSummary is empty', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': '',
      });
      expect(result, isNull);
    });

    test('returns null when classificationSummary is the wrong type', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 12345,
      });
      expect(result, isNull);
    });

    test('drops non-string entries from ID list fields instead of failing', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'industryIds': ['industry-1', 42, null, 'industry-2'],
      });

      expect(result, isNotNull);
      expect(result!.industryIds, ['industry-1', 'industry-2']);
    });

    test('treats a non-list ID field as empty rather than failing', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'technologyIds': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.technologyIds, isEmpty);
    });

    test('rejects an out-of-range enum value rather than crashing', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'riskLevel': 'catastrophic',
        'priority': 'urgent',
        'estimatedComplexity': 'extreme',
      });

      expect(result, isNotNull);
      expect(result!.riskLevel, isNull);
      expect(result.priority, isNull);
      expect(result.estimatedComplexity, isNull);
    });

    test('clamps an out-of-range confidenceScore into 0-100', () {
      final low = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'confidenceScore': -15,
      });
      final high = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'confidenceScore': 150,
      });

      expect(low!.confidenceScore, 0);
      expect(high!.confidenceScore, 100);
    });

    test('treats a non-numeric confidenceScore as absent', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'confidenceScore': 'very confident',
      });

      expect(result, isNotNull);
      expect(result!.confidenceScore, isNull);
    });

    test('treats an unparseable aiReviewedAt as absent', () {
      final result = parseAIClassificationResponse({
        'classificationSummary': 'Valid summary.',
        'aiReviewedAt': 'not-a-date',
      });

      expect(result, isNotNull);
      expect(result!.aiReviewedAt, isNull);
    });
  });
}
