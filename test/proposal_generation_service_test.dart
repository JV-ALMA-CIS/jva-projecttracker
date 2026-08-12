import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/proposal_generation_service.dart';

void main() {
  test('generateSection returns a parsed result on a valid response', () async {
    final service = ProposalGenerationService(
      invokeOverride: ({required sectionId, required mode}) async => {
        'content': 'Strong proposal content.',
        'confidenceScore': 75,
        'sourceBusinessUnitIds': ['unit-1'],
      },
    );

    final result = await service.generateSection(
      sectionId: 'section-1',
      mode: ProposalGenerationMode.generate,
    );

    expect(result.content, 'Strong proposal content.');
    expect(result.confidenceScore, 75);
    expect(result.sourceBusinessUnitIds, ['unit-1']);
  });

  test(
    'forwards the requested sectionId and mode to the invoke callback',
    () async {
      String? seenSectionId;
      String? seenMode;
      final service = ProposalGenerationService(
        invokeOverride: ({required sectionId, required mode}) async {
          seenSectionId = sectionId;
          seenMode = mode;
          return {'content': 'Ok.'};
        },
      );

      await service.generateSection(
        sectionId: 'section-42',
        mode: ProposalGenerationMode.improve,
      );

      expect(seenSectionId, 'section-42');
      expect(seenMode, 'improve');
    },
  );

  test(
    'throws ProposalGenerationException when the response is unusable (no live API call made)',
    () async {
      final service = ProposalGenerationService(
        invokeOverride: ({required sectionId, required mode}) async => {
          'confidenceScore': 80,
        },
      );

      expect(
        () => service.generateSection(
          sectionId: 'section-1',
          mode: ProposalGenerationMode.generate,
        ),
        throwsA(isA<ProposalGenerationException>()),
      );
    },
  );

  test(
    'throws ProposalGenerationException when the response is null',
    () async {
      final service = ProposalGenerationService(
        invokeOverride: ({required sectionId, required mode}) async => null,
      );

      expect(
        () => service.generateSection(
          sectionId: 'section-1',
          mode: ProposalGenerationMode.generate,
        ),
        throwsA(isA<ProposalGenerationException>()),
      );
    },
  );

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as ProposalGenerationException',
    () async {
      final service = ProposalGenerationService(
        invokeOverride: ({required sectionId, required mode}) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.generateSection(
          sectionId: 'section-1',
          mode: ProposalGenerationMode.generate,
        ),
        throwsA(
          isA<ProposalGenerationException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
