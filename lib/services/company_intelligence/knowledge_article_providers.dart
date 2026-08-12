import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/knowledge_article_insights.dart';
import 'package:jva_projecttracker/services/knowledge_article_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'experience_providers.dart';
import 'industry_providers.dart';
import 'product_providers.dart';
import 'service_providers.dart';
import 'technology_providers.dart';

final knowledgeServiceProvider = Provider((ref) => KnowledgeService());
final knowledgeArticleSummaryServiceProvider = Provider(
  (ref) => KnowledgeArticleSummaryService(),
);

final knowledgeArticlesStreamProvider = StreamProvider<List<KnowledgeArticle>>((
  ref,
) {
  return ref.watch(knowledgeServiceProvider).watchAll();
});

/// A single knowledge article by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final knowledgeArticleByIdProvider = StreamProvider.autoDispose
    .family<KnowledgeArticle?, String>((ref, id) {
      return ref.watch(knowledgeServiceProvider).watchById(id);
    });

/// Knowledge-article-scoped derived providers — the Knowledge Article
/// Workspace's equivalent of the experience* family. KnowledgeArticle
/// forward-owns all seven Company Intelligence relationship types, so
/// every related-entity provider below resolves from its own ID lists —
/// no reverse queries anywhere in this family.
final knowledgeArticleOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, articleId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all
          .where((o) => o.knowledgeArticleIds.contains(articleId))
          .toList();
    });

final knowledgeArticleProposalsProvider =
    Provider.family<List<Proposal>, String>((ref, articleId) {
      final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return proposals
          .where(
            (p) =>
                oppById[p.opportunityId]?.knowledgeArticleIds.contains(
                  articleId,
                ) ??
                false,
          )
          .toList();
    });

final knowledgeArticleSubmissionsProvider =
    Provider.family<List<Submission>, String>((ref, articleId) {
      final submissions =
          ref.watch(submissionsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return submissions
          .where(
            (s) =>
                oppById[s.opportunityId]?.knowledgeArticleIds.contains(
                  articleId,
                ) ??
                false,
          )
          .toList();
    });

final knowledgeArticleRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, articleId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.knowledgeArticleIds.contains(
                  articleId,
                ) ??
                false,
          )
          .toList();
    });

final knowledgeArticleInsightsProvider =
    Provider.family<KnowledgeArticleInsights, String>((ref, articleId) {
      final opportunities = ref.watch(
        knowledgeArticleOpportunitiesProvider(articleId),
      );
      final submissions = ref.watch(
        knowledgeArticleSubmissionsProvider(articleId),
      );
      return deriveKnowledgeArticleInsights(
        opportunities: opportunities,
        submissions: submissions,
      );
    });

final knowledgeArticleRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, articleId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedKnowledgeArticleIds.isNotEmpty) {
          return r.relatedKnowledgeArticleIds.contains(articleId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) =>
                oppById[id]?.knowledgeArticleIds.contains(articleId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final knowledgeArticleBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final units = ref.watch(businessUnitsStreamProvider).value ?? const [];
      final ids = article.businessUnitIds.toSet();
      return units.where((u) => ids.contains(u.id)).toList();
    });

final knowledgeArticleProductsProvider = Provider.family<List<Product>, String>(
  (ref, articleId) {
    final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
    if (article == null) return const [];
    final products = ref.watch(productsStreamProvider).value ?? const [];
    final ids = article.productIds.toSet();
    return products.where((p) => ids.contains(p.id)).toList();
  },
);

final knowledgeArticleServicesProvider =
    Provider.family<List<ServiceModel>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final services = ref.watch(servicesStreamProvider).value ?? const [];
      final ids = article.serviceIds.toSet();
      return services.where((s) => ids.contains(s.id)).toList();
    });

final knowledgeArticleCapabilitiesProvider =
    Provider.family<List<Capability>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final capabilities =
          ref.watch(capabilitiesStreamProvider).value ?? const [];
      final ids = article.capabilityIds.toSet();
      return capabilities.where((c) => ids.contains(c.id)).toList();
    });

final knowledgeArticleTechnologiesProvider =
    Provider.family<List<Technology>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final technologies =
          ref.watch(technologiesStreamProvider).value ?? const [];
      final ids = article.technologyIds.toSet();
      return technologies.where((t) => ids.contains(t.id)).toList();
    });

final knowledgeArticleIndustriesProvider =
    Provider.family<List<Industry>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final industries = ref.watch(industriesStreamProvider).value ?? const [];
      final ids = article.industryIds.toSet();
      return industries.where((i) => ids.contains(i.id)).toList();
    });

final knowledgeArticleExperiencesProvider =
    Provider.family<List<Experience>, String>((ref, articleId) {
      final article = ref.watch(knowledgeArticleByIdProvider(articleId)).value;
      if (article == null) return const [];
      final experiences =
          ref.watch(experiencesStreamProvider).value ?? const [];
      final ids = article.experienceIds.toSet();
      return experiences.where((e) => ids.contains(e.id)).toList();
    });
