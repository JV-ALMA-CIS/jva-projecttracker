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
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/capability_insights.dart';
import 'package:jva_projecttracker/services/capability_summary_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'experience_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';
import 'product_providers.dart';
import 'service_providers.dart';
import 'technology_providers.dart';

final capabilityServiceProvider = Provider((ref) => CapabilityService());
final capabilitySummaryServiceProvider = Provider(
  (ref) => CapabilitySummaryService(),
);

final capabilitiesStreamProvider = StreamProvider<List<Capability>>((ref) {
  return ref.watch(capabilityServiceProvider).watchAll();
});

/// A single capability by id, live.
final capabilityByIdProvider = StreamProvider.autoDispose
    .family<Capability?, String>((ref, id) {
      return ref.watch(capabilityServiceProvider).watchById(id);
    });

/// Capability-scoped derived providers. Unlike Product/Service, Capability
/// only forward-owns `productIds`/`serviceIds` — everything else that
/// references a capability (business units, technologies, industries,
/// experiences, projects) does so via its own `capabilityIds` field, so
/// those five are reverse-filtered instead of resolved from Capability's
/// own lists.
final capabilityOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, capabilityId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all.where((o) => o.capabilityIds.contains(capabilityId)).toList();
    });

final capabilityProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  capabilityId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.capabilityIds.contains(capabilityId) ??
            false,
      )
      .toList();
});

final capabilitySubmissionsProvider = Provider.family<List<Submission>, String>(
  (ref, capabilityId) {
    final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
    final opportunities =
        ref.watch(opportunitiesStreamProvider).value ?? const [];
    final oppById = {for (final o in opportunities) o.id: o};
    return submissions
        .where(
          (s) =>
              oppById[s.opportunityId]?.capabilityIds.contains(capabilityId) ??
              false,
        )
        .toList();
  },
);

final capabilityAwardedProjectsProvider =
    Provider.family<List<Project>, String>((ref, capabilityId) {
      final projects = ref.watch(projectsStreamProvider).value ?? const [];
      return projects
          .where((p) => p.capabilityIds.contains(capabilityId))
          .toList();
    });

final capabilityProductsProvider = Provider.family<List<Product>, String>((
  ref,
  capabilityId,
) {
  final capability = ref.watch(capabilityByIdProvider(capabilityId)).value;
  if (capability == null) return const [];
  final products = ref.watch(productsStreamProvider).value ?? const [];
  final ids = capability.productIds.toSet();
  return products.where((p) => ids.contains(p.id)).toList();
});

final capabilityServicesProvider = Provider.family<List<ServiceModel>, String>((
  ref,
  capabilityId,
) {
  final capability = ref.watch(capabilityByIdProvider(capabilityId)).value;
  if (capability == null) return const [];
  final services = ref.watch(servicesStreamProvider).value ?? const [];
  final ids = capability.serviceIds.toSet();
  return services.where((s) => ids.contains(s.id)).toList();
});

final capabilityBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, capabilityId) {
      final all = ref.watch(businessUnitsStreamProvider).value ?? const [];
      return all.where((u) => u.capabilityIds.contains(capabilityId)).toList();
    });

final capabilityTechnologiesProvider =
    Provider.family<List<Technology>, String>((ref, capabilityId) {
      final all = ref.watch(technologiesStreamProvider).value ?? const [];
      return all.where((t) => t.capabilityIds.contains(capabilityId)).toList();
    });

final capabilityIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  capabilityId,
) {
  final all = ref.watch(industriesStreamProvider).value ?? const [];
  return all.where((i) => i.capabilityIds.contains(capabilityId)).toList();
});

final capabilityExperiencesProvider = Provider.family<List<Experience>, String>(
  (ref, capabilityId) {
    final all = ref.watch(experiencesStreamProvider).value ?? const [];
    return all.where((e) => e.capabilityIds.contains(capabilityId)).toList();
  },
);

final capabilityKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, capabilityId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.capabilityIds.contains(capabilityId)).toList();
    });

final capabilityRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, capabilityId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedCapabilityIds.isNotEmpty) {
          return r.relatedCapabilityIds.contains(capabilityId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.capabilityIds.contains(capabilityId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final capabilityRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, capabilityId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.capabilityIds.contains(
                  capabilityId,
                ) ??
                false,
          )
          .toList();
    });

final capabilityInsightsProvider = Provider.family<CapabilityInsights, String>((
  ref,
  capabilityId,
) {
  final opportunities = ref.watch(
    capabilityOpportunitiesProvider(capabilityId),
  );
  final submissions = ref.watch(capabilitySubmissionsProvider(capabilityId));
  return deriveCapabilityInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});
