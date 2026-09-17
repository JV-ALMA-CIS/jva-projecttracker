import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/executive_summary.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/services/ai_classification_service.dart';
import 'package:jva_projecttracker/services/business_unit_seed_service.dart';
import 'package:jva_projecttracker/services/delivery_and_wins.dart';
import 'package:jva_projecttracker/services/duplicate_detection.dart';
import 'package:jva_projecttracker/services/executive_analytics.dart';
import 'package:jva_projecttracker/services/executive_intelligence_service.dart';
import 'package:jva_projecttracker/services/match_analysis_service.dart';
import 'package:jva_projecttracker/services/opportunity_business_unit_backfill_service.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/source_url_verification_service.dart';
import 'package:jva_projecttracker/services/strategic_review_service.dart';

import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';

final opportunityServiceProvider = Provider((ref) => OpportunityService());
final opportunityEventServiceProvider = Provider(
  (ref) => OpportunityEventService(),
);
final opportunityBusinessUnitBackfillServiceProvider = Provider(
  (ref) => OpportunityBusinessUnitBackfillService(),
);
final businessUnitSeedServiceProvider = Provider(
  (ref) => BusinessUnitSeedService(),
);
final sourceUrlVerificationServiceProvider = Provider(
  (ref) => SourceUrlVerificationService(),
);
final aiClassificationServiceProvider = Provider(
  (ref) => AIClassificationService(),
);
final matchAnalysisServiceProvider = Provider((ref) => MatchAnalysisService());
final strategicReviewServiceProvider = Provider(
  (ref) => StrategicReviewService(),
);
final executiveIntelligenceServiceProvider = Provider(
  (ref) => ExecutiveIntelligenceService(),
);

final opportunitiesStreamProvider = StreamProvider<List<Opportunity>>((ref) {
  return ref.watch(opportunityServiceProvider).watchAll();
});

/// Won opportunities (`awarded` or `projectStarted` pipeline stage) — the
/// Opportunities screen's "Awarded / Won" quick filter and the Dashboard's
/// "Delivery & wins" section. See `delivery_and_wins.dart`'s
/// `isWonOpportunity`.
final awardedOpportunitiesProvider = Provider<List<Opportunity>>((ref) {
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  return wonOpportunities(opportunities);
});

/// Won opportunities with no [Project] started yet — matched against
/// [projectsStreamProvider] via `sourceOpportunityId` (already loaded for
/// the Projects screen, no extra Firestore reads/N+1 lookups). Never
/// invents a Project: an opportunity leaves this list only once a real
/// Project document links back to it.
final awardedWithoutProjectProvider = Provider<List<Opportunity>>((ref) {
  final opportunities = ref.watch(awardedOpportunitiesProvider);
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return wonWithoutProject(opportunities, projects);
});

/// A single opportunity by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final opportunityByIdProvider = StreamProvider.autoDispose
    .family<Opportunity?, String>((ref, id) {
      return ref.watch(opportunityServiceProvider).watchById(id);
    });

/// An opportunity's pipeline history, live. Not autoDispose — same
/// reasoning as [productsByBusinessUnitProvider]: scoped to a single
/// "detail" screen's lifetime rather than the whole app's, but it's a list
/// (by parent id) rather than a single entity, so it follows that family's
/// convention instead of the autoDispose single-entity one.
final opportunityEventsByOpportunityProvider =
    StreamProvider.family<List<OpportunityEvent>, String>((ref, opportunityId) {
      return ref
          .watch(opportunityEventServiceProvider)
          .watchByOpportunity(opportunityId);
    });

/// The top 5 opportunities by fit score, derived from [opportunitiesStreamProvider]
/// (already ordered by `fitScorePercent` desc at the Firestore query level).
/// Off-region opportunities (see [isOffRegionOpportunity]) are excluded
/// first: they predate the discovery pipeline's geography hard-filter and
/// would otherwise still surface here by fit score alone, even though the
/// app should never suggest pursuing them.
final topOpportunitiesProvider = Provider<List<Opportunity>>((ref) {
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  return opportunities
      .where((o) => !isOffRegionOpportunity(o))
      .take(5)
      .toList();
});

/// Opportunity counts per pipeline stage, derived from
/// [opportunitiesStreamProvider] — same shape as [projectStatusCountsProvider],
/// for the Dashboard's pipeline-stage-distribution strip.
final pipelineStageCountsProvider =
    Provider<Map<OpportunityPipelineStage, int>>((ref) {
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final counts = <OpportunityPipelineStage, int>{
        for (final s in OpportunityPipelineStage.values) s: 0,
      };
      for (final o in opportunities) {
        counts[o.pipelineStage] = (counts[o.pipelineStage] ?? 0) + 1;
      }
      return counts;
    });

/// The most recent pipeline events across every opportunity, live. Backs the
/// Dashboard's "Recent activity" feed — see [OpportunityEventService.watchAll].
final recentOpportunityEventsProvider = StreamProvider<List<OpportunityEvent>>((
  ref,
) {
  return ref.watch(opportunityEventServiceProvider).watchAll(limit: 10);
});

/// The Opportunity Inbox's contents — opportunities still awaiting triage
/// (`status == discovered`), newest first. Derived from
/// [opportunitiesStreamProvider] rather than a second Firestore query, same
/// "derive from the raw stream" idiom as [pipelineStageCountsProvider].
final inboxOpportunitiesProvider = Provider<List<Opportunity>>((ref) {
  final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
  final discovered = all
      .where((o) => o.status == OpportunityStatus.discovered)
      .toList();
  discovered.sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
  return discovered;
});

/// Maps each opportunity id to the earlier opportunity it looks like a
/// duplicate of, for the Inbox's "Possible duplicate of X" banner. Pure
/// Dart, derived from the already-live [opportunitiesStreamProvider] — no
/// new reads, no AI call. See `duplicate_detection.dart`.
final opportunityDuplicatesProvider = Provider<Map<String, Opportunity>>((ref) {
  final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
  return findPossibleDuplicates(all);
});

/// The current AI Executive Summary document, live — see
/// [ExecutiveIntelligenceService.watch]. Milestone 5.1 (Executive
/// Dashboard).
final executiveSummaryStreamProvider = StreamProvider<ExecutiveSummary>((ref) {
  return ref.watch(executiveIntelligenceServiceProvider).watch();
});

/// The Executive Dashboard's KPIs (Milestone 5.1), derived entirely from
/// [opportunitiesStreamProvider] and [proposalsStreamProvider] — no new
/// Firestore reads. Each proposal's section-completion progress is pulled
/// from [proposalSectionProgressProvider], the same derivation already used
/// by the Proposal Workspace, rather than recomputed differently here.
final executiveMetricsProvider = Provider<ExecutiveMetrics>((ref) {
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];

  final progressById = <String, double>{
    for (final p in proposals)
      p.id: ref.watch(proposalSectionProgressProvider(p.id)),
  };

  return computeExecutiveMetrics(
    opportunities: opportunities,
    proposals: proposals,
    proposalProgressById: progressById,
  );
});
