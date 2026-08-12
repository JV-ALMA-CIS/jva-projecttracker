import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/business_unit_insights.dart';

void main() {
  final now = DateTime.utc(2024, 8, 1);

  Opportunity opportunity({
    required String id,
    OpportunityPipelineStage stage = OpportunityPipelineStage.discovered,
    int fitScorePercent = 0,
    DateTime? strategicReviewedAt,
    StrategicReviewRecommendation? executiveRecommendation,
  }) {
    return Opportunity(
      id: id,
      title: 'Opportunity $id',
      description: 'desc',
      sourceUrl: 'https://example.com/$id',
      discoveredAt: now,
      updatedAt: now,
      pipelineStage: stage,
      fitScorePercent: fitScorePercent,
      strategicReviewedAt: strategicReviewedAt,
      executiveRecommendation: executiveRecommendation,
    );
  }

  Submission submission({
    required String id,
    required String opportunityId,
    SubmissionStatus status = SubmissionStatus.submitted,
  }) {
    return Submission(
      id: id,
      opportunityId: opportunityId,
      proposalId: 'proposal-$id',
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('returns zeroed insights and a null win rate with no opportunities', () {
    final insights = deriveBusinessUnitInsights(
      opportunities: const [],
      submissions: const [],
    );

    expect(insights.activeOpportunityCount, 0);
    expect(insights.averageFitScorePercent, 0);
    expect(insights.reviewedOpportunityCount, 0);
    expect(insights.wonCount, 0);
    expect(insights.lostCount, 0);
    expect(insights.openSubmissionCount, 0);
    expect(insights.topOpportunity, isNull);
    expect(insights.winRate, isNull);
  });

  test('excludes lost/completed opportunities from the active count', () {
    final insights = deriveBusinessUnitInsights(
      opportunities: [
        opportunity(id: 'a', stage: OpportunityPipelineStage.qualified),
        opportunity(id: 'b', stage: OpportunityPipelineStage.lost),
        opportunity(id: 'c', stage: OpportunityPipelineStage.completed),
      ],
      submissions: const [],
    );

    expect(insights.activeOpportunityCount, 1);
  });

  test('computes win rate from awarded/projectStarted/completed vs lost', () {
    final insights = deriveBusinessUnitInsights(
      opportunities: [
        opportunity(id: 'a', stage: OpportunityPipelineStage.awarded),
        opportunity(id: 'b', stage: OpportunityPipelineStage.projectStarted),
        opportunity(id: 'c', stage: OpportunityPipelineStage.lost),
      ],
      submissions: const [],
    );

    expect(insights.wonCount, 2);
    expect(insights.lostCount, 1);
    expect(insights.winRate, closeTo(2 / 3, 0.0001));
  });

  test(
    'the top opportunity is the highest-fit reviewed one, unreviewed ones ignored',
    () {
      final insights = deriveBusinessUnitInsights(
        opportunities: [
          opportunity(id: 'high-unreviewed', fitScorePercent: 99),
          opportunity(
            id: 'low-reviewed',
            fitScorePercent: 40,
            strategicReviewedAt: now,
            executiveRecommendation: StrategicReviewRecommendation.pursue,
          ),
          opportunity(
            id: 'high-reviewed',
            fitScorePercent: 80,
            strategicReviewedAt: now,
            executiveRecommendation: StrategicReviewRecommendation.pursue,
          ),
        ],
        submissions: const [],
      );

      expect(insights.reviewedOpportunityCount, 2);
      expect(insights.topOpportunity?.id, 'high-reviewed');
    },
  );

  test('counts only open submissions', () {
    final insights = deriveBusinessUnitInsights(
      opportunities: const [],
      submissions: [
        submission(
          id: '1',
          opportunityId: 'a',
          status: SubmissionStatus.underEvaluation,
        ),
        submission(
          id: '2',
          opportunityId: 'b',
          status: SubmissionStatus.awarded,
        ),
        submission(
          id: '3',
          opportunityId: 'c',
          status: SubmissionStatus.withdrawn,
        ),
      ],
    );

    expect(insights.openSubmissionCount, 1);
  });

  test(
    'averages fit score across every opportunity, not just reviewed ones',
    () {
      final insights = deriveBusinessUnitInsights(
        opportunities: [
          opportunity(id: 'a', fitScorePercent: 40),
          opportunity(id: 'b', fitScorePercent: 60),
        ],
        submissions: const [],
      );

      expect(insights.averageFitScorePercent, 50);
    },
  );
}
