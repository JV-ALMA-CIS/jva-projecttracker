import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
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
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/technology_insights.dart';
import 'package:jva_projecttracker/services/technology_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'experience_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';
import 'product_providers.dart';

final technologyServiceProvider = Provider((ref) => TechnologyService());
final technologySummaryServiceProvider = Provider(
  (ref) => TechnologySummaryService(),
);

final technologiesStreamProvider = StreamProvider<List<Technology>>((ref) {
  return ref.watch(technologyServiceProvider).watchAll();
});

/// A single technology by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final technologyByIdProvider = StreamProvider.autoDispose
    .family<Technology?, String>((ref, id) {
      return ref.watch(technologyServiceProvider).watchById(id);
    });

/// Technology-scoped derived providers — the Technology Workspace's
/// equivalent of the capability* family. Business units/products/
/// capabilities are resolved from [Technology]'s own forward-owned ID
/// lists; opportunities/proposals/submissions/projects/industries/
/// experiences/knowledge articles are reverse-filtered via their own
/// `technologyIds` field.
final technologyOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, technologyId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all.where((o) => o.technologyIds.contains(technologyId)).toList();
    });

final technologyProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  technologyId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.technologyIds.contains(technologyId) ??
            false,
      )
      .toList();
});

final technologySubmissionsProvider = Provider.family<List<Submission>, String>(
  (ref, technologyId) {
    final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
    final opportunities =
        ref.watch(opportunitiesStreamProvider).value ?? const [];
    final oppById = {for (final o in opportunities) o.id: o};
    return submissions
        .where(
          (s) =>
              oppById[s.opportunityId]?.technologyIds.contains(technologyId) ??
              false,
        )
        .toList();
  },
);

final technologyAwardedProjectsProvider =
    Provider.family<List<Project>, String>((ref, technologyId) {
      final projects = ref.watch(projectsStreamProvider).value ?? const [];
      return projects
          .where((p) => p.technologyIds.contains(technologyId))
          .toList();
    });

final technologyBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, technologyId) {
      final technology = ref.watch(technologyByIdProvider(technologyId)).value;
      if (technology == null) return const [];
      final units = ref.watch(businessUnitsStreamProvider).value ?? const [];
      final ids = technology.businessUnitIds.toSet();
      return units.where((u) => ids.contains(u.id)).toList();
    });

final technologyProductsProvider = Provider.family<List<Product>, String>((
  ref,
  technologyId,
) {
  final technology = ref.watch(technologyByIdProvider(technologyId)).value;
  if (technology == null) return const [];
  final products = ref.watch(productsStreamProvider).value ?? const [];
  final ids = technology.productIds.toSet();
  return products.where((p) => ids.contains(p.id)).toList();
});

final technologyCapabilitiesProvider =
    Provider.family<List<Capability>, String>((ref, technologyId) {
      final technology = ref.watch(technologyByIdProvider(technologyId)).value;
      if (technology == null) return const [];
      final capabilities =
          ref.watch(capabilitiesStreamProvider).value ?? const [];
      final ids = technology.capabilityIds.toSet();
      return capabilities.where((c) => ids.contains(c.id)).toList();
    });

final technologyIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  technologyId,
) {
  final all = ref.watch(industriesStreamProvider).value ?? const [];
  return all.where((i) => i.technologyIds.contains(technologyId)).toList();
});

final technologyExperiencesProvider = Provider.family<List<Experience>, String>(
  (ref, technologyId) {
    final all = ref.watch(experiencesStreamProvider).value ?? const [];
    return all.where((e) => e.technologyIds.contains(technologyId)).toList();
  },
);

final technologyKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, technologyId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.technologyIds.contains(technologyId)).toList();
    });

final technologyRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, technologyId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedTechnologyIds.isNotEmpty) {
          return r.relatedTechnologyIds.contains(technologyId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.technologyIds.contains(technologyId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final technologyRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, technologyId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.technologyIds.contains(
                  technologyId,
                ) ??
                false,
          )
          .toList();
    });

final technologyInsightsProvider = Provider.family<TechnologyInsights, String>((
  ref,
  technologyId,
) {
  final opportunities = ref.watch(
    technologyOpportunitiesProvider(technologyId),
  );
  final submissions = ref.watch(technologySubmissionsProvider(technologyId));
  return deriveTechnologyInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});
