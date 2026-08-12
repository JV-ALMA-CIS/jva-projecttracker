import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/recommendation_engine_service.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';

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

/// Active recommendations, derived from [recommendationsStreamProvider] and
/// sorted by priority (high first) then recency — Firestore can't order by
/// the priority enum meaningfully, so this mirrors
/// [projectStatusCountsProvider]'s "derive from the raw stream" idiom rather
/// than adding a composite index for a sort Firestore can't express anyway.
final activeRecommendationsProvider = Provider<List<Recommendation>>((ref) {
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
