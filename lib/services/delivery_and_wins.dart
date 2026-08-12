import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/project.dart';

/// A project is "operational" (needs delivery attention) when its status is
/// [ProjectStatus.planned] or [ProjectStatus.running] — deliberately status-
/// only, not `sourceOpportunityId != null`, per the brief's "prefer status"
/// rule: a manually-created planned/running project is just as much an
/// active delivery concern as one started from an Opportunity, and a past
/// project that happens to have a `sourceOpportunityId` (e.g. an old
/// imported record later linked) is still historical, not active.
bool isOperationalProject(Project project) =>
    project.status == ProjectStatus.planned ||
    project.status == ProjectStatus.running;

/// Projects in [projects] that are currently active delivery — see
/// [isOperationalProject].
List<Project> operationalProjects(List<Project> projects) =>
    projects.where(isOperationalProject).toList();

/// Projects in [projects] with [ProjectStatus.past] — the Projects screen's
/// "Historical" tab, i.e. evidence-mode imports, per Phase 1.
List<Project> historicalProjects(List<Project> projects) =>
    projects.where((p) => p.status == ProjectStatus.past).toList();

/// Opportunities currently at [OpportunityPipelineStage.awarded] or
/// [OpportunityPipelineStage.projectStarted] — both count as "won": the
/// tender was won either way, `projectStarted` just additionally means
/// delivery has begun. `completed` is deliberately excluded — it's a real
/// pipeline stage too, but a completed engagement isn't what "needs
/// attention" surfaces (Dashboard/Opportunities Won filter) are for.
bool isWonOpportunity(Opportunity opportunity) =>
    opportunity.pipelineStage == OpportunityPipelineStage.awarded ||
    opportunity.pipelineStage == OpportunityPipelineStage.projectStarted;

/// Opportunities in [opportunities] that are won — see [isWonOpportunity].
List<Opportunity> wonOpportunities(List<Opportunity> opportunities) =>
    opportunities.where(isWonOpportunity).toList();

/// True when a [Project] already exists for [opportunityId] — looked up
/// from an already-streamed project list via `sourceOpportunityId`, never a
/// new Firestore read. Pure so the "Awarded, project not started" vs.
/// "Awarded, project started" distinction (A1) is independently testable.
bool hasStartedProject(String opportunityId, List<Project> projects) =>
    projects.any((p) => p.sourceOpportunityId == opportunityId);

/// Won opportunities in [opportunities] with no linked [Project] yet — the
/// Dashboard's/Opportunities-Won-filter's "Start Project needed" list.
/// Never invents a Project: an opportunity only leaves this list once a
/// real Project document with a matching `sourceOpportunityId` exists.
List<Opportunity> wonWithoutProject(
  List<Opportunity> opportunities,
  List<Project> projects,
) {
  final startedIds = projects
      .map((p) => p.sourceOpportunityId)
      .whereType<String>()
      .toSet();
  return wonOpportunities(
    opportunities,
  ).where((o) => !startedIds.contains(o.id)).toList();
}
