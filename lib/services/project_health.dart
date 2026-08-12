import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/project_deliverable.dart';
import 'package:jva_projecttracker/models/project_milestone.dart';
import 'package:jva_projecttracker/models/project_risk.dart';

/// A three-level health signal reused across schedule/budget/risk/overall —
/// deliberately generic rather than a per-dimension enum, so the Executive
/// Overview can render all four with the same badge widget.
enum ProjectHealthLevel { healthy, atRisk, critical }

const double _kBudgetAtRiskThreshold = 0.85;

/// Everything the Project Workspace's Executive Overview needs, derived
/// from data that's already streamed per-project (milestones, deliverables,
/// risks) — no new Firestore reads, no new AI call. Every non-healthy
/// signal comes with a plain-language [reasons] entry, in the same spirit
/// as this project's "confidence scores must always be explainable" rule,
/// even though this computation is deterministic arithmetic, not AI.
class ProjectHealth {
  final ProjectHealthLevel overall;
  final ProjectHealthLevel scheduleHealth;
  final ProjectHealthLevel budgetHealth;
  final ProjectHealthLevel riskHealth;

  final double completionPercent;
  final int delayedMilestonesCount;
  final int overdueDeliverablesCount;
  final int blockedDeliverablesCount;
  final int openCriticalRisksCount;
  final int openHighRisksCount;
  final double? budgetUtilization;

  final List<String> reasons;

  const ProjectHealth({
    required this.overall,
    required this.scheduleHealth,
    required this.budgetHealth,
    required this.riskHealth,
    required this.completionPercent,
    required this.delayedMilestonesCount,
    required this.overdueDeliverablesCount,
    required this.blockedDeliverablesCount,
    required this.openCriticalRisksCount,
    required this.openHighRisksCount,
    required this.budgetUtilization,
    required this.reasons,
  });
}

ProjectHealthLevel _worseOf(ProjectHealthLevel a, ProjectHealthLevel b) {
  const rank = {
    ProjectHealthLevel.healthy: 0,
    ProjectHealthLevel.atRisk: 1,
    ProjectHealthLevel.critical: 2,
  };
  return rank[a]! >= rank[b]! ? a : b;
}

ProjectHealth computeProjectHealth({
  required Project project,
  required List<ProjectMilestone> milestones,
  required List<ProjectDeliverable> deliverables,
  required List<ProjectRisk> risks,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final reasons = <String>[];

  final completedMilestones = milestones
      .where((m) => m.state(now: today) == ProjectMilestoneState.completed)
      .length;
  final completionPercent = milestones.isEmpty
      ? 0.0
      : completedMilestones / milestones.length;

  final delayedMilestones = milestones
      .where((m) => m.state(now: today) == ProjectMilestoneState.delayed)
      .length;
  final overdueDeliverables = deliverables.where((d) => d.isOverdue).length;
  final blockedDeliverables = deliverables
      .where((d) => d.status == ProjectDeliverableStatus.blocked)
      .length;

  var scheduleHealth = ProjectHealthLevel.healthy;
  if (delayedMilestones > 0 || overdueDeliverables > 0) {
    scheduleHealth = ProjectHealthLevel.critical;
    if (delayedMilestones > 0) {
      reasons.add('$delayedMilestones milestone(s) past due');
    }
    if (overdueDeliverables > 0) {
      reasons.add('$overdueDeliverables deliverable(s) overdue');
    }
  } else if (blockedDeliverables > 0) {
    scheduleHealth = ProjectHealthLevel.atRisk;
  }
  if (blockedDeliverables > 0) {
    reasons.add('$blockedDeliverables deliverable(s) blocked');
  }

  double? budgetUtilization;
  var budgetHealth = ProjectHealthLevel.healthy;
  final planned = project.plannedBudgetAmount;
  final spent = project.currentExpenditureAmount;
  if (planned != null && planned > 0 && spent != null) {
    budgetUtilization = spent / planned;
    if (budgetUtilization >= 1.0) {
      budgetHealth = ProjectHealthLevel.critical;
      reasons.add(
        'Expenditure has reached ${(budgetUtilization * 100).toStringAsFixed(0)}% of planned budget',
      );
    } else if (budgetUtilization >= _kBudgetAtRiskThreshold) {
      budgetHealth = ProjectHealthLevel.atRisk;
      reasons.add(
        'Expenditure is at ${(budgetUtilization * 100).toStringAsFixed(0)}% of planned budget',
      );
    }
  }

  final openCriticalRisks = risks
      .where(
        (r) =>
            r.status == RiskStatus.open && r.severity == RiskSeverity.critical,
      )
      .length;
  final openHighRisks = risks
      .where(
        (r) => r.status == RiskStatus.open && r.severity == RiskSeverity.high,
      )
      .length;

  var riskHealth = ProjectHealthLevel.healthy;
  if (openCriticalRisks > 0) {
    riskHealth = ProjectHealthLevel.critical;
    reasons.add('$openCriticalRisks critical risk(s) still open');
  } else if (openHighRisks > 0) {
    riskHealth = ProjectHealthLevel.atRisk;
    reasons.add('$openHighRisks high-severity risk(s) still open');
  }

  final overall = _worseOf(_worseOf(scheduleHealth, budgetHealth), riskHealth);

  return ProjectHealth(
    overall: overall,
    scheduleHealth: scheduleHealth,
    budgetHealth: budgetHealth,
    riskHealth: riskHealth,
    completionPercent: completionPercent,
    delayedMilestonesCount: delayedMilestones,
    overdueDeliverablesCount: overdueDeliverables,
    blockedDeliverablesCount: blockedDeliverables,
    openCriticalRisksCount: openCriticalRisks,
    openHighRisksCount: openHighRisks,
    budgetUtilization: budgetUtilization,
    reasons: reasons,
  );
}
