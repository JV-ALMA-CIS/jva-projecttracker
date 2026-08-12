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
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/experience_insights.dart';
import 'package:jva_projecttracker/services/experience_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';
import 'product_providers.dart';
import 'technology_providers.dart';

final experienceServiceProvider = Provider((ref) => ExperienceService());
final experienceSummaryServiceProvider = Provider(
  (ref) => ExperienceSummaryService(),
);

final experiencesStreamProvider = StreamProvider<List<Experience>>((ref) {
  return ref.watch(experienceServiceProvider).watchAll();
});

/// A single experience by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final experienceByIdProvider = StreamProvider.autoDispose
    .family<Experience?, String>((ref, id) {
      return ref.watch(experienceServiceProvider).watchById(id);
    });

/// Experience-scoped derived providers — the Experience Workspace's
/// equivalent of the industry* family. Experience forward-owns all five of
/// its relationships (business units/products/capabilities/technologies/
/// industries), so all five are resolved from its own ID lists; knowledge
/// articles are reverse-filtered via their own `experienceIds` field, and
/// the "promoted from" project is found via a single-field equality check
/// on `Project.experienceId` (singular — one experience can be promoted
/// from at most one project, per `Project.experienceId`'s doc comment).
final experienceOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, experienceId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all.where((o) => o.experienceIds.contains(experienceId)).toList();
    });

final experienceProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  experienceId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.experienceIds.contains(experienceId) ??
            false,
      )
      .toList();
});

final experienceSubmissionsProvider = Provider.family<List<Submission>, String>(
  (ref, experienceId) {
    final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
    final opportunities =
        ref.watch(opportunitiesStreamProvider).value ?? const [];
    final oppById = {for (final o in opportunities) o.id: o};
    return submissions
        .where(
          (s) =>
              oppById[s.opportunityId]?.experienceIds.contains(experienceId) ??
              false,
        )
        .toList();
  },
);

final experienceRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, experienceId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.experienceIds.contains(
                  experienceId,
                ) ??
                false,
          )
          .toList();
    });

final experienceInsightsProvider = Provider.family<ExperienceInsights, String>((
  ref,
  experienceId,
) {
  final opportunities = ref.watch(
    experienceOpportunitiesProvider(experienceId),
  );
  final submissions = ref.watch(experienceSubmissionsProvider(experienceId));
  return deriveExperienceInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});

final experienceRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, experienceId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedExperienceIds.isNotEmpty) {
          return r.relatedExperienceIds.contains(experienceId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.experienceIds.contains(experienceId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final experienceBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, experienceId) {
      final experience = ref.watch(experienceByIdProvider(experienceId)).value;
      if (experience == null) return const [];
      final units = ref.watch(businessUnitsStreamProvider).value ?? const [];
      final ids = experience.businessUnitIds.toSet();
      return units.where((u) => ids.contains(u.id)).toList();
    });

final experienceProductsProvider = Provider.family<List<Product>, String>((
  ref,
  experienceId,
) {
  final experience = ref.watch(experienceByIdProvider(experienceId)).value;
  if (experience == null) return const [];
  final products = ref.watch(productsStreamProvider).value ?? const [];
  final ids = experience.productIds.toSet();
  return products.where((p) => ids.contains(p.id)).toList();
});

final experienceCapabilitiesProvider =
    Provider.family<List<Capability>, String>((ref, experienceId) {
      final experience = ref.watch(experienceByIdProvider(experienceId)).value;
      if (experience == null) return const [];
      final capabilities =
          ref.watch(capabilitiesStreamProvider).value ?? const [];
      final ids = experience.capabilityIds.toSet();
      return capabilities.where((c) => ids.contains(c.id)).toList();
    });

final experienceTechnologiesProvider =
    Provider.family<List<Technology>, String>((ref, experienceId) {
      final experience = ref.watch(experienceByIdProvider(experienceId)).value;
      if (experience == null) return const [];
      final technologies =
          ref.watch(technologiesStreamProvider).value ?? const [];
      final ids = experience.technologyIds.toSet();
      return technologies.where((t) => ids.contains(t.id)).toList();
    });

final experienceIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  experienceId,
) {
  final experience = ref.watch(experienceByIdProvider(experienceId)).value;
  if (experience == null) return const [];
  final industries = ref.watch(industriesStreamProvider).value ?? const [];
  final ids = experience.industryIds.toSet();
  return industries.where((i) => ids.contains(i.id)).toList();
});

final experienceKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, experienceId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.experienceIds.contains(experienceId)).toList();
    });

final experiencePromotedFromProjectProvider = Provider.family<Project?, String>(
  (ref, experienceId) {
    final projects = ref.watch(projectsStreamProvider).value ?? const [];
    for (final p in projects) {
      if (p.experienceId == experienceId) return p;
    }
    return null;
  },
);
