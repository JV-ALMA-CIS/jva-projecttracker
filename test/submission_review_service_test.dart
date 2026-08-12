import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/services/submission_review_service.dart';

void main() {
  test('generateReview returns a parsed result on a valid response', () async {
    final service = SubmissionReviewService(
      invokeOverride: ({required proposalId}) async => {
        'overallReadiness': 'ready',
        'riskLevel': 'low',
        'strongSections': ['Team: highly qualified'],
      },
    );

    final result = await service.generateReview(proposalId: 'proposal-1');

    expect(result.overallReadiness, SubmissionReviewReadiness.ready);
    expect(result.riskLevel, RiskLevel.low);
    expect(result.strongSections, ['Team: highly qualified']);
  });

  test('forwards the requested proposalId to the invoke callback', () async {
    String? seenProposalId;
    final service = SubmissionReviewService(
      invokeOverride: ({required proposalId}) async {
        seenProposalId = proposalId;
        return {'overallReadiness': 'needsWork'};
      },
    );

    await service.generateReview(proposalId: 'proposal-42');

    expect(seenProposalId, 'proposal-42');
  });

  test(
    'throws SubmissionReviewException when the response is null (no live API call made)',
    () async {
      final service = SubmissionReviewService(
        invokeOverride: ({required proposalId}) async => null,
      );

      expect(
        () => service.generateReview(proposalId: 'proposal-1'),
        throwsA(isA<SubmissionReviewException>()),
      );
    },
  );

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as SubmissionReviewException',
    () async {
      final service = SubmissionReviewService(
        invokeOverride: ({required proposalId}) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.generateReview(proposalId: 'proposal-1'),
        throwsA(
          isA<SubmissionReviewException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
