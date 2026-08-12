import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/submission.dart';

const _wonStages = {
  OpportunityPipelineStage.awarded,
  OpportunityPipelineStage.projectStarted,
  OpportunityPipelineStage.completed,
};

const _closedStages = {
  OpportunityPipelineStage.lost,
  OpportunityPipelineStage.completed,
};

/// Executive-summary KPIs for one Technology — mirrors `CapabilityInsights`/
/// `ProductInsights`/`ServiceInsights` exactly. See
/// `TechnologyWorkspaceScreen`.
class TechnologyInsights {
  const TechnologyInsights({
    required this.activeOpportunityCount,
    required this.averageFitScorePercent,
    required this.reviewedOpportunityCount,
    required this.wonCount,
    required this.lostCount,
    required this.openSubmissionCount,
    this.topOpportunity,
  });

  final int activeOpportunityCount;
  final int averageFitScorePercent;
  final int reviewedOpportunityCount;
  final int wonCount;
  final int lostCount;
  final int openSubmissionCount;
  final Opportunity? topOpportunity;

  double? get winRate {
    final decided = wonCount + lostCount;
    if (decided == 0) return null;
    return wonCount / decided;
  }
}

TechnologyInsights deriveTechnologyInsights({
  required List<Opportunity> opportunities,
  required List<Submission> submissions,
}) {
  final active = opportunities
      .where((o) => !_closedStages.contains(o.pipelineStage))
      .length;
  final reviewed = opportunities
      .where((o) => o.strategicReviewedAt != null)
      .toList();
  final won = opportunities
      .where((o) => _wonStages.contains(o.pipelineStage))
      .length;
  final lost = opportunities
      .where((o) => o.pipelineStage == OpportunityPipelineStage.lost)
      .length;
  final openSubmissions = submissions.where((s) => !s.status.isClosed).length;

  Opportunity? topOpportunity;
  for (final o in reviewed) {
    if (topOpportunity == null ||
        o.fitScorePercent > topOpportunity.fitScorePercent) {
      topOpportunity = o;
    }
  }

  return TechnologyInsights(
    activeOpportunityCount: active,
    averageFitScorePercent: opportunities.isEmpty
        ? 0
        : (opportunities.map((o) => o.fitScorePercent).reduce((a, b) => a + b) /
                  opportunities.length)
              .round(),
    reviewedOpportunityCount: reviewed.length,
    wonCount: won,
    lostCount: lost,
    openSubmissionCount: openSubmissions,
    topOpportunity: topOpportunity,
  );
}
