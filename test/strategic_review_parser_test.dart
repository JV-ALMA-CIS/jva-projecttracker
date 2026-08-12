import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/strategic_review_parser.dart';

void main() {
  group('parseStrategicReviewResponse — valid input', () {
    test('parses a fully-populated strategic review response', () {
      final result = parseStrategicReviewResponse({
        'executiveRecommendation': 'pursue',
        'executiveSummary': 'Strong strategic fit, recommend pursuing.',
        'strategicStrengths': ['Deep water infrastructure experience'],
        'strategicWeaknesses': ['No local office in the region'],
        'strategicRisks': ['Tight delivery timeline'],
        'mitigationStrategies': ['Partner with a local subcontractor'],
        'competitiveAdvantages': ['Proven track record with similar tenders'],
        'missingRequirements': ['ISO 9001 certification'],
        'strategicReviewBusinessUnitIds': ['unit-1'],
        'strategicReviewProductIds': ['product-1'],
        'strategicReviewServiceIds': ['service-1'],
        'strategicReviewCapabilityIds': ['cap-1'],
        'strategicReviewTechnologyIds': ['tech-1'],
        'strategicReviewExperienceIds': ['experience-1', 'experience-2'],
        'strategicReviewKnowledgeArticleIds': ['article-1'],
        'proposalPositioningStrategy':
            'Lead with the water infrastructure case study.',
        'nextRecommendedActions': ['Schedule a scoping call with the client'],
        'strategicReviewedAt': '2024-08-01T12:00:00.000Z',
      });

      expect(result, isNotNull);
      expect(
        result!.executiveRecommendation,
        StrategicReviewRecommendation.pursue,
      );
      expect(
        result.executiveSummary,
        'Strong strategic fit, recommend pursuing.',
      );
      expect(result.strategicStrengths, [
        'Deep water infrastructure experience',
      ]);
      expect(result.strategicWeaknesses, ['No local office in the region']);
      expect(result.strategicRisks, ['Tight delivery timeline']);
      expect(result.mitigationStrategies, [
        'Partner with a local subcontractor',
      ]);
      expect(result.competitiveAdvantages, [
        'Proven track record with similar tenders',
      ]);
      expect(result.missingRequirements, ['ISO 9001 certification']);
      expect(result.strategicReviewBusinessUnitIds, ['unit-1']);
      expect(result.strategicReviewProductIds, ['product-1']);
      expect(result.strategicReviewServiceIds, ['service-1']);
      expect(result.strategicReviewCapabilityIds, ['cap-1']);
      expect(result.strategicReviewTechnologyIds, ['tech-1']);
      expect(result.strategicReviewExperienceIds, [
        'experience-1',
        'experience-2',
      ]);
      expect(result.strategicReviewKnowledgeArticleIds, ['article-1']);
      expect(
        result.proposalPositioningStrategy,
        'Lead with the water infrastructure case study.',
      );
      expect(result.nextRecommendedActions, [
        'Schedule a scoping call with the client',
      ]);
      expect(
        result.strategicReviewedAt,
        DateTime.parse('2024-08-01T12:00:00.000Z'),
      );
    });

    test('defaults missing recommendation/lists gracefully', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Thin data, proceed with caution.',
      });

      expect(result, isNotNull);
      expect(result!.executiveRecommendation, isNull);
      expect(result.strategicStrengths, isEmpty);
      expect(result.strategicWeaknesses, isEmpty);
      expect(result.strategicRisks, isEmpty);
      expect(result.mitigationStrategies, isEmpty);
      expect(result.competitiveAdvantages, isEmpty);
      expect(result.missingRequirements, isEmpty);
      expect(result.strategicReviewBusinessUnitIds, isEmpty);
      expect(result.strategicReviewProductIds, isEmpty);
      expect(result.strategicReviewServiceIds, isEmpty);
      expect(result.strategicReviewCapabilityIds, isEmpty);
      expect(result.strategicReviewTechnologyIds, isEmpty);
      expect(result.strategicReviewExperienceIds, isEmpty);
      expect(result.strategicReviewKnowledgeArticleIds, isEmpty);
      expect(result.proposalPositioningStrategy, isNull);
      expect(result.nextRecommendedActions, isEmpty);
      expect(result.strategicReviewedAt, isNull);
    });
  });

  group('parseStrategicReviewResponse — malformed/partial input', () {
    test('returns null for a null payload', () {
      expect(parseStrategicReviewResponse(null), isNull);
    });

    test('returns null when executiveSummary is missing', () {
      final result = parseStrategicReviewResponse({
        'executiveRecommendation': 'pursue',
      });
      expect(result, isNull);
    });

    test('returns null when executiveSummary is empty', () {
      final result = parseStrategicReviewResponse({'executiveSummary': ''});
      expect(result, isNull);
    });

    test('returns null when executiveSummary is the wrong type', () {
      final result = parseStrategicReviewResponse({'executiveSummary': 12345});
      expect(result, isNull);
    });

    test('treats an invalid executiveRecommendation as absent', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Valid.',
        'executiveRecommendation': 'maybe',
      });

      expect(result, isNotNull);
      expect(result!.executiveRecommendation, isNull);
    });

    test('drops non-string entries from ID list fields instead of failing', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Valid.',
        'strategicReviewProductIds': ['product-1', 42, null, 'product-2'],
      });

      expect(result, isNotNull);
      expect(result!.strategicReviewProductIds, ['product-1', 'product-2']);
    });

    test('treats a non-list ID field as empty rather than failing', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Valid.',
        'strategicReviewExperienceIds': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.strategicReviewExperienceIds, isEmpty);
    });

    test('drops non-string entries from narrative list fields', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Valid.',
        'strategicStrengths': ['Good fit', 42, null],
        'strategicRisks': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.strategicStrengths, ['Good fit']);
      expect(result.strategicRisks, isEmpty);
    });

    test('treats an unparseable strategicReviewedAt as absent', () {
      final result = parseStrategicReviewResponse({
        'executiveSummary': 'Valid.',
        'strategicReviewedAt': 'not-a-date',
      });

      expect(result, isNotNull);
      expect(result!.strategicReviewedAt, isNull);
    });
  });
}
