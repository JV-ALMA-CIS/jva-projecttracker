import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/match_analysis_parser.dart';

void main() {
  group('parseMatchAnalysisResponse — valid input', () {
    test('parses a fully-populated match analysis response', () {
      final result = parseMatchAnalysisResponse({
        'overallMatchScore': 87,
        'businessUnitScore': 90,
        'productScore': 80,
        'serviceScore': 70,
        'capabilityScore': 85,
        'technologyScore': 75,
        'industryScore': 95,
        'experienceScore': 88,
        'knowledgeScore': 60,
        'strategicRecommendation': 'Strong strategic fit, pursue actively.',
        'recommendedProductIds': ['product-1'],
        'recommendedBusinessUnitIds': ['unit-1'],
        'recommendedExperienceIds': ['experience-1', 'experience-2'],
        'recommendedKnowledgeArticleIds': ['article-1'],
        'strengths': ['Deep water infrastructure experience'],
        'gaps': ['No prior work in this specific region'],
        'risks': ['Tight delivery timeline'],
        'nextActions': ['Schedule a scoping call with the client'],
        'matchAnalyzedAt': '2024-08-01T12:00:00.000Z',
      });

      expect(result, isNotNull);
      expect(result!.overallMatchScore, 87);
      expect(result.businessUnitScore, 90);
      expect(result.productScore, 80);
      expect(result.serviceScore, 70);
      expect(result.capabilityScore, 85);
      expect(result.technologyScore, 75);
      expect(result.industryScore, 95);
      expect(result.experienceScore, 88);
      expect(result.knowledgeScore, 60);
      expect(
        result.strategicRecommendation,
        'Strong strategic fit, pursue actively.',
      );
      expect(result.recommendedProductIds, ['product-1']);
      expect(result.recommendedBusinessUnitIds, ['unit-1']);
      expect(result.recommendedExperienceIds, ['experience-1', 'experience-2']);
      expect(result.recommendedKnowledgeArticleIds, ['article-1']);
      expect(result.strengths, ['Deep water infrastructure experience']);
      expect(result.gaps, ['No prior work in this specific region']);
      expect(result.risks, ['Tight delivery timeline']);
      expect(result.nextActions, ['Schedule a scoping call with the client']);
      expect(
        result.matchAnalyzedAt,
        DateTime.parse('2024-08-01T12:00:00.000Z'),
      );
    });

    test('defaults missing scores/recommendations/lists gracefully', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Thin data, proceed with caution.',
      });

      expect(result, isNotNull);
      expect(result!.overallMatchScore, isNull);
      expect(result.businessUnitScore, isNull);
      expect(result.productScore, isNull);
      expect(result.serviceScore, isNull);
      expect(result.capabilityScore, isNull);
      expect(result.technologyScore, isNull);
      expect(result.industryScore, isNull);
      expect(result.experienceScore, isNull);
      expect(result.knowledgeScore, isNull);
      expect(result.recommendedProductIds, isEmpty);
      expect(result.recommendedBusinessUnitIds, isEmpty);
      expect(result.recommendedExperienceIds, isEmpty);
      expect(result.recommendedKnowledgeArticleIds, isEmpty);
      expect(result.strengths, isEmpty);
      expect(result.gaps, isEmpty);
      expect(result.risks, isEmpty);
      expect(result.nextActions, isEmpty);
      expect(result.matchAnalyzedAt, isNull);
    });
  });

  group('parseMatchAnalysisResponse — malformed/partial input', () {
    test('returns null for a null payload', () {
      expect(parseMatchAnalysisResponse(null), isNull);
    });

    test('returns null when strategicRecommendation is missing', () {
      final result = parseMatchAnalysisResponse({'overallMatchScore': 80});
      expect(result, isNull);
    });

    test('returns null when strategicRecommendation is empty', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': '',
      });
      expect(result, isNull);
    });

    test('returns null when strategicRecommendation is the wrong type', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 12345,
      });
      expect(result, isNull);
    });

    test('drops non-string entries from ID list fields instead of failing', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'recommendedProductIds': ['product-1', 42, null, 'product-2'],
      });

      expect(result, isNotNull);
      expect(result!.recommendedProductIds, ['product-1', 'product-2']);
    });

    test('treats a non-list ID field as empty rather than failing', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'recommendedExperienceIds': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.recommendedExperienceIds, isEmpty);
    });

    test('clamps out-of-range scores into 0-100 for every score field', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'overallMatchScore': -20,
        'businessUnitScore': 500,
      });

      expect(result, isNotNull);
      expect(result!.overallMatchScore, 0);
      expect(result.businessUnitScore, 100);
    });

    test('treats a non-numeric score as absent', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'overallMatchScore': 'very good',
      });

      expect(result, isNotNull);
      expect(result!.overallMatchScore, isNull);
    });

    test('drops non-string entries from narrative list fields', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'strengths': ['Good fit', 42, null],
        'risks': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.strengths, ['Good fit']);
      expect(result.risks, isEmpty);
    });

    test('treats an unparseable matchAnalyzedAt as absent', () {
      final result = parseMatchAnalysisResponse({
        'strategicRecommendation': 'Valid.',
        'matchAnalyzedAt': 'not-a-date',
      });

      expect(result, isNotNull);
      expect(result!.matchAnalyzedAt, isNull);
    });
  });
}
