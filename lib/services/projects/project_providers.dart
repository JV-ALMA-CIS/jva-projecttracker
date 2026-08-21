import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/project_deliverable.dart';
import 'package:jva_projecttracker/models/project_event.dart';
import 'package:jva_projecttracker/models/project_milestone.dart';
import 'package:jva_projecttracker/models/project_risk.dart';
import 'package:jva_projecttracker/services/application_service.dart';
import 'package:jva_projecttracker/services/currency_service.dart';
import 'package:jva_projecttracker/services/delivery_and_wins.dart';
import 'package:jva_projecttracker/services/project_deliverable_service.dart';
import 'package:jva_projecttracker/services/project_event_service.dart';
import 'package:jva_projecttracker/services/project_extraction_service.dart';
import 'package:jva_projecttracker/services/project_health.dart';
import 'package:jva_projecttracker/services/project_milestone_service.dart';
import 'package:jva_projecttracker/services/project_portfolio_metrics.dart';
import 'package:jva_projecttracker/services/project_related_knowledge.dart';
import 'package:jva_projecttracker/services/project_risk_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'dart:async';

final projectServiceProvider = Provider((ref) => ProjectService());
final applicationServiceProvider = Provider((ref) => ApplicationService());
final projectExtractionServiceProvider = Provider(
  (ref) => ProjectExtractionService(),
);
final currencyServiceProvider = Provider((ref) => CurrencyService());
final projectMilestoneServiceProvider = Provider(
  (ref) => ProjectMilestoneService(),
);
final projectDeliverableServiceProvider = Provider(
  (ref) => ProjectDeliverableService(),
);
final projectRiskServiceProvider = Provider((ref) => ProjectRiskService());
final projectEventServiceProvider = Provider((ref) => ProjectEventService());

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectServiceProvider).watchAll();
});

/// Active-delivery projects (planned/running) — the Projects screen's
/// "Active delivery" tab and the Dashboard's "Delivery & wins" section. See
/// `delivery_and_wins.dart`'s `isOperationalProject` for the exact rule.
final operationalProjectsProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return operationalProjects(projects);
});

/// Historical/evidence projects (`ProjectStatus.past`) — the Projects
/// screen's "Historical" tab.
final historicalProjectsProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return historicalProjects(projects);
});

final applicationsStreamProvider = StreamProvider<List<CompanyApplication>>((
  ref,
) {
  return ref.watch(applicationServiceProvider).watchAll();
});

// --- Project Delivery Workspace (Milestone 5.1) ---

final projectMilestonesByProjectIdProvider =
    StreamProvider.family<List<ProjectMilestone>, String>((ref, projectId) {
      return ref
          .watch(projectMilestoneServiceProvider)
          .watchByProjectId(projectId);
    });

final projectDeliverablesByProjectIdProvider =
    StreamProvider.family<List<ProjectDeliverable>, String>((ref, projectId) {
      return ref
          .watch(projectDeliverableServiceProvider)
          .watchByProjectId(projectId);
    });

final projectRisksByProjectIdProvider =
    StreamProvider.family<List<ProjectRisk>, String>((ref, projectId) {
      return ref.watch(projectRiskServiceProvider).watchByProjectId(projectId);
    });

final projectEventsByProjectIdProvider =
    StreamProvider.family<List<ProjectEvent>, String>((ref, projectId) {
      return ref.watch(projectEventServiceProvider).watchByProjectId(projectId);
    });

/// A single project by id, live. Scoped to navigation (edit screen) rather
/// than the app lifetime, so autoDispose is correct here — unlike the
/// top-level [projectsStreamProvider], which backs an always-visible list.
final projectByIdProvider = StreamProvider.autoDispose.family<Project?, String>(
  (ref, id) {
    return ref.watch(projectServiceProvider).watchById(id);
  },
);

/// The Project Workspace's Executive Overview health — derived from
/// [projectMilestonesByProjectIdProvider]/[projectDeliverablesByProjectIdProvider]/
/// [projectRisksByProjectIdProvider], already streamed for the workspace
/// itself; no separate reads. See `project_health.dart`.
///
/// `autoDispose` because this depends on [projectByIdProvider], which is
/// itself `autoDispose`. Keeping this as a plain (non-autoDispose) `Provider`
/// let it outlive its dependency's disposal window: when the last watcher
/// briefly dropped away mid-rebuild (e.g. Dashboard's attention list and
/// `ProjectWorkspaceScreen` both watching the same `projectId` across
/// frames), Riverpod would dispose and recreate `projectByIdProvider`
/// synchronously inside another widget's build phase, tripping
/// "setState()/markNeedsBuild() called during build" in
/// `ProjectWorkspaceScreen._buildBody`. Matching the autoDispose lifecycle
/// here keeps both providers disposed/recreated together.
final projectHealthProvider = Provider.autoDispose
    .family<ProjectHealth, String>((ref, projectId) {
      final project = ref.watch(projectByIdProvider(projectId)).value;
      final milestones =
          ref.watch(projectMilestonesByProjectIdProvider(projectId)).value ??
          const [];
      final deliverables =
          ref.watch(projectDeliverablesByProjectIdProvider(projectId)).value ??
          const [];
      final risks =
          ref.watch(projectRisksByProjectIdProvider(projectId)).value ??
          const [];

      if (project == null) {
        return const ProjectHealth(
          overall: ProjectHealthLevel.healthy,
          scheduleHealth: ProjectHealthLevel.healthy,
          budgetHealth: ProjectHealthLevel.healthy,
          riskHealth: ProjectHealthLevel.healthy,
          completionPercent: 0,
          delayedMilestonesCount: 0,
          overdueDeliverablesCount: 0,
          blockedDeliverablesCount: 0,
          openCriticalRisksCount: 0,
          openHighRisksCount: 0,
          budgetUtilization: null,
          reasons: [],
        );
      }

      return computeProjectHealth(
        project: project,
        milestones: milestones,
        deliverables: deliverables,
        risks: risks,
      );
    });

/// Related/similar previous projects for the Related Knowledge panel. See
/// `project_related_knowledge.dart`.
final relatedProjectsProvider = Provider.family<List<RelatedProject>, String>((
  ref,
  projectId,
) {
  final project = ref.watch(projectByIdProvider(projectId)).value;
  if (project == null) return const [];
  final all = ref.watch(projectsStreamProvider).value ?? const [];
  return computeRelatedProjects(project: project, allProjects: all);
});

/// The Projects list page's portfolio dashboard (Active/At Risk/Delayed/
/// Completed/Budget Alerts/Attention Required). Watches every project's
/// health via [projectHealthProvider] — reasonable at current portfolio
/// sizes; see Architectural Recommendations if the project count grows
/// large enough to make this expensive.
final projectPortfolioMetricsProvider = Provider<ProjectPortfolioMetrics>((
  ref,
) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  final healthByProjectId = {
    for (final p in projects) p.id: ref.watch(projectHealthProvider(p.id)),
  };
  return computeProjectPortfolioMetrics(
    projects: projects,
    healthByProjectId: healthByProjectId,
  );
});

/// Awarded/in-delivery projects whose [ProjectHealth] has at least one
/// explainable reason (delayed milestone, overdue/blocked deliverable, open
/// critical/high risk, budget overrun) — the Dashboard's "Projects needing
/// attention" source. Deliberately excludes `ProjectStatus.past`: a
/// completed project's historical schedule/budget slippage isn't something
/// the Dashboard should keep flagging as live attention-worthy. Reuses
/// [projectHealthProvider] (already computed per project for the workspace),
/// same no-new-reads shape as [projectPortfolioMetricsProvider].
final projectsNeedingAttentionProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return projects
      .where((p) => p.status != ProjectStatus.past)
      .where((p) => ref.watch(projectHealthProvider(p.id)).reasons.isNotEmpty)
      .toList();
});

/// Project counts per status, derived from [projectsStreamProvider]. Kept as
/// a separate provider (rather than computed inline in the dashboard) so the
/// dashboard can `.select()` a single status count and skip rebuilding when
/// unrelated counts change.
final projectStatusCountsProvider = Provider<Map<ProjectStatus, int>>((ref) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  final counts = <ProjectStatus, int>{
    for (final s in ProjectStatus.values) s: 0,
  };
  for (final p in projects) {
    counts[p.status] = (counts[p.status] ?? 0) + 1;
  }
  return counts;
});

/// A single application by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final applicationByIdProvider = StreamProvider.autoDispose
    .family<CompanyApplication?, String>((ref, id) {
      return ref.watch(applicationServiceProvider).watchById(id);
    });

/// A single project by opportunity id (convenience wrapper around
/// [ProjectService.watchByOpportunityId]).
final projectByOpportunityIdProvider = StreamProvider.autoDispose
    .family<Project?, String>((ref, opportunityId) {
      return ref
          .watch(projectServiceProvider)
          .watchByOpportunityId(opportunityId);
    });

/// Live exchange rates from [base] to the other supported currencies, kept
/// alive for 30 minutes so switching fields/screens doesn't re-hit the API
/// on every rebuild, while still refreshing periodically rather than being
/// pinned to a stale value for the whole session.
final exchangeRatesProvider = FutureProvider.autoDispose
    .family<Map<String, double>, String>((ref, base) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 30), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(currencyServiceProvider).fetchRates(base);
    });
