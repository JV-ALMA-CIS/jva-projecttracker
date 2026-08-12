import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';

/// Opportunity statuses that count as "no longer active" for pipeline-value,
/// workload, and risk/confidence-watchlist purposes — the deal is already
/// decided (won/lost) or was never a real pursuit (dismissed/archived).
const Set<OpportunityStatus> _closedStatuses = {
  OpportunityStatus.won,
  OpportunityStatus.lost,
  OpportunityStatus.dismissed,
  OpportunityStatus.archived,
};

/// A simple, explainable win-probability weight per pipeline stage, used
/// only for Milestone 5.1's single "Revenue forecast" KPI card. This is a
/// placeholder heuristic, not a statistical model — Milestone 5.5 (Revenue
/// Forecasting) is where best-case/worst-case/weighted scenarios with
/// stated assumptions belong. Values are deliberately monotonic with the
/// pipeline's real progression so the number is easy to sanity-check.
const Map<OpportunityPipelineStage, double> _stageForecastWeight = {
  OpportunityPipelineStage.discovered: 0.05,
  OpportunityPipelineStage.classified: 0.10,
  OpportunityPipelineStage.reviewed: 0.15,
  OpportunityPipelineStage.qualified: 0.25,
  OpportunityPipelineStage.approved: 0.35,
  OpportunityPipelineStage.proposalStarted: 0.40,
  OpportunityPipelineStage.proposalReady: 0.50,
  OpportunityPipelineStage.submitted: 0.60,
  OpportunityPipelineStage.evaluation: 0.65,
  OpportunityPipelineStage.negotiation: 0.80,
  OpportunityPipelineStage.awarded: 1.0,
  OpportunityPipelineStage.projectStarted: 1.0,
  OpportunityPipelineStage.completed: 1.0,
  OpportunityPipelineStage.lost: 0.0,
};

/// How many days out counts as an "upcoming" submission deadline.
const int kUpcomingSubmissionWindowDays = 14;

/// A minimum confidence score (out of 100) for an opportunity to appear in
/// the "high-confidence" watchlist.
const int kHighConfidenceThreshold = 80;

/// Everything the Executive Dashboard (Milestone 5.1) needs, derived once
/// from opportunities/proposals that are already streamed elsewhere in the
/// app — no new Firestore reads, no duplicated data, per this project's
/// "Analytics must derive from existing... data" rule.
class ExecutiveMetrics {
  final int totalActiveOpportunities;
  final double pipelineValue;

  final int wonCount;
  final int lostCount;
  final double winRate;
  final double lossRate;

  final double revenueForecast;

  final int totalProposals;
  final int proposalsReadyForReview;
  final double averageProposalReadiness;

  final Map<String, int> byBusinessUnitId;
  final Map<String, int> byIndustryId;

  final Map<String, int> workloadByAssignee;
  final int unassignedActiveCount;

  final List<Opportunity> upcomingSubmissions;
  final List<Opportunity> highRiskOpportunities;
  final List<Opportunity> highConfidenceOpportunities;

  const ExecutiveMetrics({
    this.totalActiveOpportunities = 0,
    this.pipelineValue = 0,
    this.wonCount = 0,
    this.lostCount = 0,
    this.winRate = 0,
    this.lossRate = 0,
    this.revenueForecast = 0,
    this.totalProposals = 0,
    this.proposalsReadyForReview = 0,
    this.averageProposalReadiness = 0,
    this.byBusinessUnitId = const {},
    this.byIndustryId = const {},
    this.workloadByAssignee = const {},
    this.unassignedActiveCount = 0,
    this.upcomingSubmissions = const [],
    this.highRiskOpportunities = const [],
    this.highConfidenceOpportunities = const [],
  });
}

/// Computes [ExecutiveMetrics] from the opportunity/proposal lists the
/// dashboard already has watched, plus each proposal's section-completion
/// progress (0-1), keyed by `Proposal.id`, exactly as already computed by
/// `proposalSectionProgressProvider` for the Proposal Workspace — reused
/// here rather than re-derived differently.
ExecutiveMetrics computeExecutiveMetrics({
  required List<Opportunity> opportunities,
  required List<Proposal> proposals,
  required Map<String, double> proposalProgressById,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  final active = opportunities
      .where((o) => !_closedStatuses.contains(o.status))
      .toList();

  final won = opportunities.where((o) => o.status == OpportunityStatus.won);
  final lost = opportunities.where((o) => o.status == OpportunityStatus.lost);
  final decided = won.length + lost.length;

  final pipelineValue = active.fold<double>(
    0,
    (sum, o) => sum + (o.estimatedBudget ?? 0),
  );

  final revenueForecast = active.fold<double>(0, (sum, o) {
    final budget = o.estimatedBudget ?? 0;
    final weight = _stageForecastWeight[o.pipelineStage] ?? 0.1;
    return sum + budget * weight;
  });

  final byBusinessUnitId = <String, int>{};
  final byIndustryId = <String, int>{};
  final workloadByAssignee = <String, int>{};
  var unassignedActive = 0;

  final upcomingSubmissions = <Opportunity>[];
  final highRisk = <Opportunity>[];
  final highConfidence = <Opportunity>[];

  for (final o in opportunities) {
    for (final id in o.businessUnitIds) {
      byBusinessUnitId.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final id in o.industryIds) {
      byIndustryId.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  for (final o in active) {
    final assignee = o.assignedTo;
    if (assignee == null || assignee.trim().isEmpty) {
      unassignedActive += 1;
    } else {
      workloadByAssignee.update(assignee, (v) => v + 1, ifAbsent: () => 1);
    }

    if (o.riskLevel == RiskLevel.high) highRisk.add(o);
    if ((o.confidenceScore ?? 0) >= kHighConfidenceThreshold) {
      highConfidence.add(o);
    }

    final deadline = o.deadline;
    if (deadline != null && o.submittedDate == null) {
      final daysOut = deadline.difference(today).inDays;
      if (daysOut >= 0 && daysOut <= kUpcomingSubmissionWindowDays) {
        upcomingSubmissions.add(o);
      }
    }
  }

  upcomingSubmissions.sort((a, b) => a.deadline!.compareTo(b.deadline!));
  highRisk.sort(
    (a, b) => (b.confidenceScore ?? 0).compareTo(a.confidenceScore ?? 0),
  );
  highConfidence.sort(
    (a, b) => (b.confidenceScore ?? 0).compareTo(a.confidenceScore ?? 0),
  );

  final readyForReview = proposals
      .where((p) => p.status == ProposalStatus.readyForReview)
      .length;

  final averageReadiness = proposals.isEmpty
      ? 0.0
      : proposals.fold<double>(
              0,
              (sum, p) => sum + (proposalProgressById[p.id] ?? 0),
            ) /
            proposals.length;

  return ExecutiveMetrics(
    totalActiveOpportunities: active.length,
    pipelineValue: pipelineValue,
    wonCount: won.length,
    lostCount: lost.length,
    winRate: decided == 0 ? 0 : won.length / decided,
    lossRate: decided == 0 ? 0 : lost.length / decided,
    revenueForecast: revenueForecast,
    totalProposals: proposals.length,
    proposalsReadyForReview: readyForReview,
    averageProposalReadiness: averageReadiness,
    byBusinessUnitId: byBusinessUnitId,
    byIndustryId: byIndustryId,
    workloadByAssignee: workloadByAssignee,
    unassignedActiveCount: unassignedActive,
    upcomingSubmissions: upcomingSubmissions,
    highRiskOpportunities: highRisk,
    highConfidenceOpportunities: highConfidence,
  );
}
