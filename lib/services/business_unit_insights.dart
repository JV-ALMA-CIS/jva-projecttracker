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

/// Executive-summary KPIs + AI strategic-review rollup for one Business
/// Unit, derived purely from its own opportunities/submissions already
/// loaded elsewhere — no new Firestore reads, no new AI call. See
/// `BusinessUnitWorkspaceScreen`.
class BusinessUnitInsights {
  const BusinessUnitInsights({
    required this.activeOpportunityCount,
    required this.averageFitScorePercent,
    required this.reviewedOpportunityCount,
    required this.wonCount,
    required this.lostCount,
    required this.openSubmissionCount,
    this.topOpportunity,
  });

  final int activeOpportunityCount;

  /// 0 when there are no opportunities at all — never a fabricated score.
  final int averageFitScorePercent;
  final int reviewedOpportunityCount;
  final int wonCount;
  final int lostCount;
  final int openSubmissionCount;

  /// The highest-fit-score opportunity with a completed strategic review, if
  /// any — surfaced as the headline AI insight rather than a raw list.
  final Opportunity? topOpportunity;

  /// Win rate among decided opportunities (won vs lost), 0-1. `null` when
  /// nothing has been decided yet, never rendered as a fabricated 0%.
  double? get winRate {
    final decided = wonCount + lostCount;
    if (decided == 0) return null;
    return wonCount / decided;
  }
}

BusinessUnitInsights deriveBusinessUnitInsights({
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

  return BusinessUnitInsights(
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
