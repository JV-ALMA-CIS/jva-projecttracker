import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/product_insights.dart';
import 'package:jva_projecttracker/services/product_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'capability_providers.dart';
import 'experience_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';
import 'technology_providers.dart';

final productServiceProvider = Provider((ref) => ProductService());
final productSummaryServiceProvider = Provider(
  (ref) => ProductSummaryService(),
);

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productServiceProvider).watchAll();
});

final productsByBusinessUnitProvider =
    StreamProvider.family<List<Product>, String>((ref, businessUnitId) {
      return ref
          .watch(productServiceProvider)
          .watchByBusinessUnit(businessUnitId);
    });

/// A single product by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final productByIdProvider = StreamProvider.autoDispose.family<Product?, String>(
  (ref, id) {
    return ref.watch(productServiceProvider).watchById(id);
  },
);

/// Product-scoped derived providers — the Product Workspace's equivalent of
/// the businessUnit* family above, one level down the Company Intelligence
/// graph. Capabilities/technologies/industries are resolved from
/// [Product]'s own forward-owned ID lists (like businessUnitCapabilities*
/// does for BusinessUnit); opportunities/proposals/submissions/projects/
/// experiences/knowledge articles are reverse-filtered via their own
/// `productIds` field (since Product doesn't forward-own those).
final productOpportunitiesProvider = Provider.family<List<Opportunity>, String>(
  (ref, productId) {
    final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
    return all.where((o) => o.productIds.contains(productId)).toList();
  },
);

final productProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  productId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.productIds.contains(productId) ?? false,
      )
      .toList();
});

final productSubmissionsProvider = Provider.family<List<Submission>, String>((
  ref,
  productId,
) {
  final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return submissions
      .where(
        (s) =>
            oppById[s.opportunityId]?.productIds.contains(productId) ?? false,
      )
      .toList();
});

final productAwardedProjectsProvider = Provider.family<List<Project>, String>((
  ref,
  productId,
) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return projects.where((p) => p.productIds.contains(productId)).toList();
});

final productCapabilitiesProvider = Provider.family<List<Capability>, String>((
  ref,
  productId,
) {
  final product = ref.watch(productByIdProvider(productId)).value;
  if (product == null) return const [];
  final capabilities = ref.watch(capabilitiesStreamProvider).value ?? const [];
  final ids = product.capabilityIds.toSet();
  return capabilities.where((c) => ids.contains(c.id)).toList();
});

final productTechnologiesProvider = Provider.family<List<Technology>, String>((
  ref,
  productId,
) {
  final product = ref.watch(productByIdProvider(productId)).value;
  if (product == null) return const [];
  final technologies = ref.watch(technologiesStreamProvider).value ?? const [];
  final ids = product.technologyIds.toSet();
  return technologies.where((t) => ids.contains(t.id)).toList();
});

final productIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  productId,
) {
  final product = ref.watch(productByIdProvider(productId)).value;
  if (product == null) return const [];
  final industries = ref.watch(industriesStreamProvider).value ?? const [];
  final ids = product.industryIds.toSet();
  return industries.where((i) => ids.contains(i.id)).toList();
});

final productExperiencesProvider = Provider.family<List<Experience>, String>((
  ref,
  productId,
) {
  final experiences = ref.watch(experiencesStreamProvider).value ?? const [];
  return experiences.where((e) => e.productIds.contains(productId)).toList();
});

final productKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, productId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.productIds.contains(productId)).toList();
    });

final productRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, productId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedProductIds.isNotEmpty) {
          return r.relatedProductIds.contains(productId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.productIds.contains(productId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final productRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, productId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.productIds.contains(productId) ??
                false,
          )
          .toList();
    });

final productInsightsProvider = Provider.family<ProductInsights, String>((
  ref,
  productId,
) {
  final opportunities = ref.watch(productOpportunitiesProvider(productId));
  final submissions = ref.watch(productSubmissionsProvider(productId));
  return deriveProductInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});
