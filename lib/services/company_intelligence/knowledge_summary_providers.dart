import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';

import '../opportunities/opportunity_providers.dart';
import '../recommendations/recommendation_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'experience_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';
import 'product_providers.dart';
import 'service_providers.dart';
import 'technology_providers.dart';

/// Per-entity-type summaries backing the Company Intelligence Knowledge
/// Workspace landing screen (count / recently updated / related
/// opportunities / AI health) — see `knowledge_health.dart`. Each is a pure
/// derivation over streams already watched elsewhere in the app; the
/// `opportunityReferencedIds`/`recommendationReferencedIds` closures supply
/// exactly the fields that apply to that entity type (not every type has a
/// match-analysis "recommended" or strategic-review variant).
final businessUnitKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<BusinessUnit>>((ref) {
      return summarizeKnowledgeEntities<BusinessUnit>(
        entities: ref.watch(businessUnitsStreamProvider).value ?? const [],
        idOf: (b) => b.id,
        updatedAtOf: (b) => b.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.businessUnitIds,
          ...o.recommendedBusinessUnitIds,
          ...o.strategicReviewBusinessUnitIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedBusinessUnitIds},
      );
    });

final productKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<Product>>((ref) {
      return summarizeKnowledgeEntities<Product>(
        entities: ref.watch(productsStreamProvider).value ?? const [],
        idOf: (p) => p.id,
        updatedAtOf: (p) => p.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.productIds,
          ...o.recommendedProductIds,
          ...o.strategicReviewProductIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedProductIds},
      );
    });

final serviceKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<ServiceModel>>((ref) {
      return summarizeKnowledgeEntities<ServiceModel>(
        entities: ref.watch(servicesStreamProvider).value ?? const [],
        idOf: (s) => s.id,
        updatedAtOf: (s) => s.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.serviceIds,
          ...o.strategicReviewServiceIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedServiceIds},
      );
    });

final capabilityKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<Capability>>((ref) {
      return summarizeKnowledgeEntities<Capability>(
        entities: ref.watch(capabilitiesStreamProvider).value ?? const [],
        idOf: (c) => c.id,
        updatedAtOf: (c) => c.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.capabilityIds,
          ...o.strategicReviewCapabilityIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedCapabilityIds},
      );
    });

final technologyKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<Technology>>((ref) {
      return summarizeKnowledgeEntities<Technology>(
        entities: ref.watch(technologiesStreamProvider).value ?? const [],
        idOf: (t) => t.id,
        updatedAtOf: (t) => t.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.technologyIds,
          ...o.strategicReviewTechnologyIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedTechnologyIds},
      );
    });

final industryKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<Industry>>((ref) {
      return summarizeKnowledgeEntities<Industry>(
        entities: ref.watch(industriesStreamProvider).value ?? const [],
        idOf: (i) => i.id,
        updatedAtOf: (i) => i.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {...o.industryIds},
        recommendationReferencedIds: (r) => {...r.relatedIndustryIds},
      );
    });

final experienceKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<Experience>>((ref) {
      return summarizeKnowledgeEntities<Experience>(
        entities: ref.watch(experiencesStreamProvider).value ?? const [],
        idOf: (e) => e.id,
        updatedAtOf: (e) => e.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.experienceIds,
          ...o.recommendedExperienceIds,
          ...o.strategicReviewExperienceIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedExperienceIds},
      );
    });

final knowledgeArticleKnowledgeSummaryProvider =
    Provider<KnowledgeEntitySummary<KnowledgeArticle>>((ref) {
      return summarizeKnowledgeEntities<KnowledgeArticle>(
        entities: ref.watch(knowledgeArticlesStreamProvider).value ?? const [],
        idOf: (k) => k.id,
        updatedAtOf: (k) => k.updatedAt,
        opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
        recommendations:
            ref.watch(recommendationsStreamProvider).value ?? const [],
        opportunityReferencedIds: (o) => {
          ...o.knowledgeArticleIds,
          ...o.recommendedKnowledgeArticleIds,
          ...o.strategicReviewKnowledgeArticleIds,
        },
        recommendationReferencedIds: (r) => {...r.relatedKnowledgeArticleIds},
      );
    });

int _recentlyUpdatedCount<T>(
  List<T> items,
  DateTime Function(T) updatedAtOf,
  DateTime cutoff,
) {
  return items.where((i) => updatedAtOf(i).isAfter(cutoff)).length;
}

/// Portfolio-wide totals for the Knowledge Workspace's executive summary —
/// combines the 8 per-type summaries above rather than recomputing anything
/// independently.
class KnowledgeGraphOverview {
  const KnowledgeGraphOverview({
    required this.totalEntities,
    required this.capabilityGapCount,
    required this.recentlyUpdatedCount,
  });

  final int totalEntities;

  /// How many of the 8 entity types currently have zero opportunities/
  /// recommendations referencing any of their members.
  final int capabilityGapCount;

  /// How many entities (across all 8 types) were updated in the last 30
  /// days.
  final int recentlyUpdatedCount;
}

final knowledgeGraphOverviewProvider = Provider<KnowledgeGraphOverview>((ref) {
  final businessUnits = ref.watch(businessUnitKnowledgeSummaryProvider);
  final products = ref.watch(productKnowledgeSummaryProvider);
  final services = ref.watch(serviceKnowledgeSummaryProvider);
  final capabilities = ref.watch(capabilityKnowledgeSummaryProvider);
  final technologies = ref.watch(technologyKnowledgeSummaryProvider);
  final industries = ref.watch(industryKnowledgeSummaryProvider);
  final experiences = ref.watch(experienceKnowledgeSummaryProvider);
  final knowledgeArticles = ref.watch(knowledgeArticleKnowledgeSummaryProvider);

  final counts = [
    businessUnits.count,
    products.count,
    services.count,
    capabilities.count,
    technologies.count,
    industries.count,
    experiences.count,
    knowledgeArticles.count,
  ];
  final healths = [
    businessUnits.health,
    products.health,
    services.health,
    capabilities.health,
    technologies.health,
    industries.health,
    experiences.health,
    knowledgeArticles.health,
  ];

  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final recentlyUpdatedCount =
      _recentlyUpdatedCount(
        ref.watch(businessUnitsStreamProvider).value ?? const [],
        (b) => b.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(productsStreamProvider).value ?? const [],
        (p) => p.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(servicesStreamProvider).value ?? const [],
        (s) => s.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(capabilitiesStreamProvider).value ?? const [],
        (c) => c.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(technologiesStreamProvider).value ?? const [],
        (t) => t.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(industriesStreamProvider).value ?? const [],
        (i) => i.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(experiencesStreamProvider).value ?? const [],
        (e) => e.updatedAt,
        cutoff,
      ) +
      _recentlyUpdatedCount(
        ref.watch(knowledgeArticlesStreamProvider).value ?? const [],
        (k) => k.updatedAt,
        cutoff,
      );

  return KnowledgeGraphOverview(
    totalEntities: counts.fold(0, (a, b) => a + b),
    capabilityGapCount: healths.where((h) => h == KnowledgeHealth.gap).length,
    recentlyUpdatedCount: recentlyUpdatedCount,
  );
});
