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
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/industry_insights.dart';
import 'package:jva_projecttracker/services/industry_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'experience_providers.dart';
import 'knowledge_article_providers.dart';
import 'product_providers.dart';
import 'technology_providers.dart';

final industryServiceProvider = Provider((ref) => IndustryService());
final industrySummaryServiceProvider = Provider(
  (ref) => IndustrySummaryService(),
);

final industriesStreamProvider = StreamProvider<List<Industry>>((ref) {
  return ref.watch(industryServiceProvider).watchAll();
});

/// A single industry by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final industryByIdProvider = StreamProvider.autoDispose
    .family<Industry?, String>((ref, id) {
      return ref.watch(industryServiceProvider).watchById(id);
    });

/// Industry-scoped derived providers — the Industry Workspace's equivalent
/// of the technology* family. Industry forward-owns all five of its
/// relationships (businessUnits/products/capabilities/technologies/
/// experiences), so all five are resolved from its own ID lists;
/// opportunities/proposals/submissions/projects/knowledge articles are
/// reverse-filtered via their own `industryIds` field.
final industryOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, industryId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all.where((o) => o.industryIds.contains(industryId)).toList();
    });

final industryProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  industryId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.industryIds.contains(industryId) ?? false,
      )
      .toList();
});

final industrySubmissionsProvider = Provider.family<List<Submission>, String>((
  ref,
  industryId,
) {
  final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return submissions
      .where(
        (s) =>
            oppById[s.opportunityId]?.industryIds.contains(industryId) ?? false,
      )
      .toList();
});

final industryAwardedProjectsProvider = Provider.family<List<Project>, String>((
  ref,
  industryId,
) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return projects.where((p) => p.industryIds.contains(industryId)).toList();
});

final industryBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, industryId) {
      final industry = ref.watch(industryByIdProvider(industryId)).value;
      if (industry == null) return const [];
      final units = ref.watch(businessUnitsStreamProvider).value ?? const [];
      final ids = industry.businessUnitIds.toSet();
      return units.where((u) => ids.contains(u.id)).toList();
    });

final industryProductsProvider = Provider.family<List<Product>, String>((
  ref,
  industryId,
) {
  final industry = ref.watch(industryByIdProvider(industryId)).value;
  if (industry == null) return const [];
  final products = ref.watch(productsStreamProvider).value ?? const [];
  final ids = industry.productIds.toSet();
  return products.where((p) => ids.contains(p.id)).toList();
});

final industryCapabilitiesProvider = Provider.family<List<Capability>, String>((
  ref,
  industryId,
) {
  final industry = ref.watch(industryByIdProvider(industryId)).value;
  if (industry == null) return const [];
  final capabilities = ref.watch(capabilitiesStreamProvider).value ?? const [];
  final ids = industry.capabilityIds.toSet();
  return capabilities.where((c) => ids.contains(c.id)).toList();
});

final industryTechnologiesProvider = Provider.family<List<Technology>, String>((
  ref,
  industryId,
) {
  final industry = ref.watch(industryByIdProvider(industryId)).value;
  if (industry == null) return const [];
  final technologies = ref.watch(technologiesStreamProvider).value ?? const [];
  final ids = industry.technologyIds.toSet();
  return technologies.where((t) => ids.contains(t.id)).toList();
});

final industryExperiencesProvider = Provider.family<List<Experience>, String>((
  ref,
  industryId,
) {
  final industry = ref.watch(industryByIdProvider(industryId)).value;
  if (industry == null) return const [];
  final experiences = ref.watch(experiencesStreamProvider).value ?? const [];
  final ids = industry.experienceIds.toSet();
  return experiences.where((e) => ids.contains(e.id)).toList();
});

final industryKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, industryId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.industryIds.contains(industryId)).toList();
    });

final industryRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, industryId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedIndustryIds.isNotEmpty) {
          return r.relatedIndustryIds.contains(industryId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.industryIds.contains(industryId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final industryRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, industryId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.industryIds.contains(industryId) ??
                false,
          )
          .toList();
    });

final industryInsightsProvider = Provider.family<IndustryInsights, String>((
  ref,
  industryId,
) {
  final opportunities = ref.watch(industryOpportunitiesProvider(industryId));
  final submissions = ref.watch(industrySubmissionsProvider(industryId));
  return deriveIndustryInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});
