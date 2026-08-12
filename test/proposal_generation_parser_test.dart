import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/proposal_generation_parser.dart';

void main() {
  group('parseProposalGenerationResponse — valid input', () {
    test('parses a fully-populated generation response', () {
      final result = parseProposalGenerationResponse({
        'content': 'JV ALMA CIS proposes a phased rollout...',
        'confidenceScore': 82,
        'sourceBusinessUnitIds': ['unit-1'],
        'sourceProductIds': ['product-1'],
        'sourceServiceIds': ['service-1'],
        'sourceCapabilityIds': ['cap-1'],
        'sourceTechnologyIds': ['tech-1'],
        'sourceIndustryIds': ['industry-1'],
        'sourceExperienceIds': ['experience-1', 'experience-2'],
        'sourceKnowledgeArticleIds': ['article-1'],
        'aiGeneratedAt': '2024-08-01T12:00:00.000Z',
      });

      expect(result, isNotNull);
      expect(result!.content, 'JV ALMA CIS proposes a phased rollout...');
      expect(result.confidenceScore, 82);
      expect(result.sourceBusinessUnitIds, ['unit-1']);
      expect(result.sourceProductIds, ['product-1']);
      expect(result.sourceServiceIds, ['service-1']);
      expect(result.sourceCapabilityIds, ['cap-1']);
      expect(result.sourceTechnologyIds, ['tech-1']);
      expect(result.sourceIndustryIds, ['industry-1']);
      expect(result.sourceExperienceIds, ['experience-1', 'experience-2']);
      expect(result.sourceKnowledgeArticleIds, ['article-1']);
      expect(result.aiGeneratedAt, DateTime.parse('2024-08-01T12:00:00.000Z'));
    });

    test('defaults missing confidence/source lists/date gracefully', () {
      final result = parseProposalGenerationResponse({
        'content': 'Some content.',
      });

      expect(result, isNotNull);
      expect(result!.confidenceScore, isNull);
      expect(result.sourceBusinessUnitIds, isEmpty);
      expect(result.sourceProductIds, isEmpty);
      expect(result.sourceServiceIds, isEmpty);
      expect(result.sourceCapabilityIds, isEmpty);
      expect(result.sourceTechnologyIds, isEmpty);
      expect(result.sourceIndustryIds, isEmpty);
      expect(result.sourceExperienceIds, isEmpty);
      expect(result.sourceKnowledgeArticleIds, isEmpty);
      expect(result.aiGeneratedAt, isNull);
    });

    test('clamps an out-of-range confidence score into 0-100', () {
      final result = parseProposalGenerationResponse({
        'content': 'Some content.',
        'confidenceScore': 142,
      });

      expect(result!.confidenceScore, 100);
    });
  });

  group('parseProposalGenerationResponse — malformed/partial input', () {
    test('returns null for a null payload', () {
      expect(parseProposalGenerationResponse(null), isNull);
    });

    test('returns null when content is missing', () {
      final result = parseProposalGenerationResponse({'confidenceScore': 80});
      expect(result, isNull);
    });

    test('returns null when content is empty', () {
      final result = parseProposalGenerationResponse({'content': ''});
      expect(result, isNull);
    });

    test('returns null when content is the wrong type', () {
      final result = parseProposalGenerationResponse({'content': 12345});
      expect(result, isNull);
    });

    test('drops non-string entries from source ID list fields', () {
      final result = parseProposalGenerationResponse({
        'content': 'Valid.',
        'sourceProductIds': ['product-1', 42, null, 'product-2'],
      });

      expect(result, isNotNull);
      expect(result!.sourceProductIds, ['product-1', 'product-2']);
    });

    test('treats a non-list source ID field as empty rather than failing', () {
      final result = parseProposalGenerationResponse({
        'content': 'Valid.',
        'sourceExperienceIds': 'not-a-list',
      });

      expect(result, isNotNull);
      expect(result!.sourceExperienceIds, isEmpty);
    });

    test('treats an unparseable aiGeneratedAt as absent', () {
      final result = parseProposalGenerationResponse({
        'content': 'Valid.',
        'aiGeneratedAt': 'not-a-date',
      });

      expect(result, isNotNull);
      expect(result!.aiGeneratedAt, isNull);
    });
  });
}
