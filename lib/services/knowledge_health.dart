import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';

/// How well a Company Intelligence entity type is connected to the actual
/// opportunity pipeline — a categorical signal, never a percentage/gauge
/// (see ADR-004's "no new percentage visual language" rule, which this
/// mirrors). `noData` means the collection is empty; `gap` means every
/// entity of this type is currently unreferenced by any opportunity or AI
/// recommendation — a literal "capability gap."
enum KnowledgeHealth { noData, gap, attention, covered }

/// A summary of one Company Intelligence entity type (e.g. every
/// [Capability]), for the Company Intelligence Knowledge Workspace landing
/// screen. See [summarizeKnowledgeEntities].
class KnowledgeEntitySummary<T> {
  const KnowledgeEntitySummary({
    required this.count,
    required this.mostRecentlyUpdated,
    required this.relatedOpportunityCount,
    required this.health,
  });

  final int count;
  final T? mostRecentlyUpdated;

  /// The number of opportunities that reference at least one entity of this
  /// type, across every AI layer (classification/match-analysis/strategic-
  /// review) plus every active AI recommendation.
  final int relatedOpportunityCount;
  final KnowledgeHealth health;
}

const _kCoveredThreshold = 0.5;

/// Derives a [KnowledgeEntitySummary] for one Company Intelligence entity
/// type from data already loaded elsewhere in the app ([entities],
/// [opportunities], [recommendations]) — no new Firestore reads, no AI call,
/// same "derive from the raw stream" idiom as `activeRecommendationsProvider`/
/// `pipelineStageCountsProvider`.
///
/// [opportunityReferencedIds]/[recommendationReferencedIds] extract the set
/// of this-entity-type IDs a given opportunity/recommendation references —
/// callers pass in exactly the fields that apply to their entity type (e.g.
/// Industry only has a classification-layer field and a
/// `relatedIndustryIds` field; most other types also have match-analysis
/// and/or strategic-review variants).
KnowledgeEntitySummary<T> summarizeKnowledgeEntities<T>({
  required List<T> entities,
  required String Function(T) idOf,
  required DateTime Function(T) updatedAtOf,
  required List<Opportunity> opportunities,
  required List<Recommendation> recommendations,
  required Set<String> Function(Opportunity) opportunityReferencedIds,
  required Set<String> Function(Recommendation) recommendationReferencedIds,
}) {
  if (entities.isEmpty) {
    return KnowledgeEntitySummary<T>(
      count: 0,
      mostRecentlyUpdated: null,
      relatedOpportunityCount: 0,
      health: KnowledgeHealth.noData,
    );
  }

  T mostRecent = entities.first;
  for (final entity in entities.skip(1)) {
    if (updatedAtOf(entity).isAfter(updatedAtOf(mostRecent))) {
      mostRecent = entity;
    }
  }

  final knownIds = entities.map(idOf).toSet();

  final referencedIds = <String>{};
  var relatedOpportunityCount = 0;
  for (final opportunity in opportunities) {
    final ids = opportunityReferencedIds(opportunity);
    if (ids.isNotEmpty) relatedOpportunityCount += 1;
    referencedIds.addAll(ids);
  }
  for (final recommendation in recommendations) {
    referencedIds.addAll(recommendationReferencedIds(recommendation));
  }

  final coverage =
      referencedIds.intersection(knownIds).length / knownIds.length;
  final health = coverage == 0
      ? KnowledgeHealth.gap
      : coverage < _kCoveredThreshold
      ? KnowledgeHealth.attention
      : KnowledgeHealth.covered;

  return KnowledgeEntitySummary<T>(
    count: entities.length,
    mostRecentlyUpdated: mostRecent,
    relatedOpportunityCount: relatedOpportunityCount,
    health: health,
  );
}
