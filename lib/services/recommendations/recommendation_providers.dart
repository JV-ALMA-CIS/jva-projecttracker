import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/recommendation_engine_service.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:jva_projecttracker/services/related_opportunity_triage.dart';
import 'package:jva_projecttracker/services/opportunities/opportunity_providers.dart';

final recommendationServiceProvider = Provider(
  (ref) => RecommendationService(),
);
final recommendationEngineServiceProvider = Provider(
  (ref) => RecommendationEngineService(),
);

final recommendationsStreamProvider = StreamProvider<List<Recommendation>>((
  ref,
) {
  return ref.watch(recommendationServiceProvider).watchAll();
});

int _recommendationPriorityRank(OpportunityPriority priority) =>
    switch (priority) {
      OpportunityPriority.high => 2,
      OpportunityPriority.medium => 1,
      OpportunityPriority.low => 0,
    };

/// Every active recommendation, derived from [recommendationsStreamProvider]
/// and sorted by priority (high first) then recency — including outdated ones
/// (see [outdatedRecommendationsProvider]). Firestore can't order by the
/// priority enum meaningfully, so this is derived from the raw stream.
final allActiveRecommendationsProvider = Provider<List<Recommendation>>((ref) {
  final all = ref.watch(recommendationsStreamProvider).value ?? const [];
  final active = all
      .where((r) => r.status == RecommendationStatus.active)
      .toList();
  active.sort((a, b) {
    final byPriority = _recommendationPriorityRank(
      b.priority,
    ).compareTo(_recommendationPriorityRank(a.priority));
    if (byPriority != 0) return byPriority;
    return b.generatedAt.compareTo(a.generatedAt);
  });
  return active;
});

Map<String, Opportunity> _opportunitiesById(Ref ref) => <String, Opportunity>{
  for (final o
      in ref.watch(opportunitiesStreamProvider).value ?? const <Opportunity>[])
    o.id: o,
};

/// Active recommendations that are about specific opportunities which have
/// ALL closed or passed their deadline — nothing left to act on. Kept out of
/// the Dashboard and Notifications, and folded on the Recommendations
/// screen. Nothing in the database changes, so they reappear if anything is
/// reopened.
final outdatedRecommendationsProvider = Provider<List<Recommendation>>((ref) {
  final byId = _opportunitiesById(ref);
  final now = DateTime.now();
  return ref
      .watch(allActiveRecommendationsProvider)
      .where((r) => isOutdatedRecommendation(r, byId, now))
      .toList();
});

/// Active recommendations that still have something to act on.
final activeRecommendationsProvider = Provider<List<Recommendation>>((ref) {
  final outdated = {
    for (final r in ref.watch(outdatedRecommendationsProvider)) r.id,
  };
  return ref
      .watch(allActiveRecommendationsProvider)
      .where((r) => !outdated.contains(r.id))
      .toList();
});

/// The top 3 active recommendations, for the Dashboard's compact section —
/// same "derive, then take(n)" shape as [topOpportunitiesProvider].
final topRecommendationsProvider = Provider<List<Recommendation>>((ref) {
  return ref.watch(activeRecommendationsProvider).take(3).toList();
});

/// Recommendations that reference a specific opportunity — for the
/// Opportunity Workspace's "Related recommendations" section. Same
/// derive-then-filter idiom as [activeRecommendationsProvider], just keyed
/// by opportunity id instead of a global filter.
final recommendationsForOpportunityProvider =
    Provider.family<List<Recommendation>, String>((ref, opportunityId) {
      return ref
              .watch(recommendationsStreamProvider)
              .value
              ?.where((r) => r.relatedOpportunityIds.contains(opportunityId))
              .toList() ??
          const [];
    });
