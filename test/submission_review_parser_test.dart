import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/services/submission_review_parser.dart';

void main() {
  test('parses a fully-populated valid response', () {
    final result = parseSubmissionReviewResponse({
      'overallReadiness': 'ready',
      'riskLevel': 'low',
      'missingEvidence': ['Need ISO 9001 certificate'],
      'weakSections': ['Methodology: too generic'],
      'strongSections': ['Team: highly qualified'],
      'complianceConcerns': ['No local registration on file'],
      'recommendedImprovements': ['Add a risk mitigation table'],
      'reviewedAt': '2024-08-01T00:00:00.000Z',
    });

    expect(result, isNotNull);
    expect(result!.overallReadiness, SubmissionReviewReadiness.ready);
    expect(result.riskLevel, RiskLevel.low);
    expect(result.missingEvidence, ['Need ISO 9001 certificate']);
    expect(result.weakSections, ['Methodology: too generic']);
    expect(result.strongSections, ['Team: highly qualified']);
    expect(result.complianceConcerns, ['No local registration on file']);
    expect(result.recommendedImprovements, ['Add a risk mitigation table']);
    expect(result.reviewedAt, DateTime.parse('2024-08-01T00:00:00.000Z'));
  });

  test('returns null for a null payload', () {
    expect(parseSubmissionReviewResponse(null), isNull);
  });

  test('defaults missing/invalid enums gracefully', () {
    final result = parseSubmissionReviewResponse({});

    expect(result, isNotNull);
    expect(result!.overallReadiness, SubmissionReviewReadiness.needsWork);
    expect(result.riskLevel, RiskLevel.medium);
    expect(result.missingEvidence, isEmpty);
  });

  test('treats an invalid overallReadiness/riskLevel as absent', () {
    final result = parseSubmissionReviewResponse({
      'overallReadiness': 'super-ready',
      'riskLevel': 'extreme',
    });

    expect(result!.overallReadiness, SubmissionReviewReadiness.needsWork);
    expect(result.riskLevel, RiskLevel.medium);
  });

  test('drops non-string entries and empty strings from list fields', () {
    final result = parseSubmissionReviewResponse({
      'missingEvidence': ['Valid item', 123, '', null, true],
    });

    expect(result!.missingEvidence, ['Valid item']);
  });

  test('treats a non-list field as empty rather than failing', () {
    final result = parseSubmissionReviewResponse({
      'weakSections': 'not a list',
    });

    expect(result!.weakSections, isEmpty);
  });

  test('treats an unparseable reviewedAt as absent', () {
    final result = parseSubmissionReviewResponse({'reviewedAt': 'not-a-date'});

    expect(result!.reviewedAt, isNull);
  });
}
