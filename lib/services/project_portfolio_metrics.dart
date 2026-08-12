import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/project_health.dart';

/// The Projects list page's portfolio-level summary — every count here is
/// just a filter over [ProjectHealth]s already computed per project
/// (see `computeProjectHealth`); nothing new is derived. "AI Attention
/// Required" is named to match the brief but is, honestly, the same
/// explainable-reasons signal as everything else here — reusing existing
/// logic rather than a new AI pass, per this project's AI constraint for
/// this milestone.
class ProjectPortfolioMetrics {
  final int activeCount;
  final int delayedCount;
  final int atRiskCount;
  final int completedCount;
  final int budgetAlertsCount;
  final int attentionRequiredCount;

  const ProjectPortfolioMetrics({
    this.activeCount = 0,
    this.delayedCount = 0,
    this.atRiskCount = 0,
    this.completedCount = 0,
    this.budgetAlertsCount = 0,
    this.attentionRequiredCount = 0,
  });
}

ProjectPortfolioMetrics computeProjectPortfolioMetrics({
  required List<Project> projects,
  required Map<String, ProjectHealth> healthByProjectId,
}) {
  var active = 0;
  var delayed = 0;
  var atRisk = 0;
  var completed = 0;
  var budgetAlerts = 0;
  var attention = 0;

  for (final project in projects) {
    if (project.status == ProjectStatus.running) active++;
    if (project.status == ProjectStatus.past) completed++;

    final health = healthByProjectId[project.id];
    if (health == null) continue;

    if (health.scheduleHealth == ProjectHealthLevel.critical) delayed++;
    if (health.overall != ProjectHealthLevel.healthy &&
        health.scheduleHealth != ProjectHealthLevel.critical) {
      atRisk++;
    }
    if (health.budgetHealth != ProjectHealthLevel.healthy) budgetAlerts++;
    if (health.reasons.isNotEmpty) attention++;
  }

  return ProjectPortfolioMetrics(
    activeCount: active,
    delayedCount: delayed,
    atRiskCount: atRisk,
    completedCount: completed,
    budgetAlertsCount: budgetAlerts,
    attentionRequiredCount: attention,
  );
}
