import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/service_insights.dart';
import 'package:jva_projecttracker/services/service_summary_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../projects/project_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';
import '../submissions/submission_providers.dart';
import 'business_unit_providers.dart';
import 'capability_providers.dart';
import 'industry_providers.dart';
import 'knowledge_article_providers.dart';

final serviceServiceProvider = Provider((ref) => ServiceService());
final serviceSummaryServiceProvider = Provider(
  (ref) => ServiceSummaryService(),
);

final servicesStreamProvider = StreamProvider<List<ServiceModel>>((ref) {
  return ref.watch(serviceServiceProvider).watchAll();
});

final servicesByBusinessUnitProvider =
    StreamProvider.family<List<ServiceModel>, String>((ref, businessUnitId) {
      return ref
          .watch(serviceServiceProvider)
          .watchByBusinessUnit(businessUnitId);
    });

/// A single service by id, live.
final serviceByIdProvider = StreamProvider.autoDispose
    .family<ServiceModel?, String>((ref, id) {
      return ref.watch(serviceServiceProvider).watchById(id);
    });

/// Service-scoped derived providers — the Service Workspace's equivalent of
/// the product* family above. Capabilities/industries/business units are
/// resolved from [ServiceModel]'s own forward-owned ID lists; opportunities/
/// proposals/submissions/projects/knowledge articles are reverse-filtered
/// via their own `serviceIds` field. There is no `serviceExperiencesProvider`
/// — `Experience` has no `serviceIds` field, so that section simply doesn't
/// exist for Services rather than referencing a nonexistent field.
final serviceOpportunitiesProvider = Provider.family<List<Opportunity>, String>(
  (ref, serviceId) {
    final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
    return all.where((o) => o.serviceIds.contains(serviceId)).toList();
  },
);

final serviceProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  serviceId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.serviceIds.contains(serviceId) ?? false,
      )
      .toList();
});

final serviceSubmissionsProvider = Provider.family<List<Submission>, String>((
  ref,
  serviceId,
) {
  final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return submissions
      .where(
        (s) =>
            oppById[s.opportunityId]?.serviceIds.contains(serviceId) ?? false,
      )
      .toList();
});

final serviceAwardedProjectsProvider = Provider.family<List<Project>, String>((
  ref,
  serviceId,
) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  return projects.where((p) => p.serviceIds.contains(serviceId)).toList();
});

final serviceCapabilitiesProvider = Provider.family<List<Capability>, String>((
  ref,
  serviceId,
) {
  final service = ref.watch(serviceByIdProvider(serviceId)).value;
  if (service == null) return const [];
  final capabilities = ref.watch(capabilitiesStreamProvider).value ?? const [];
  final ids = service.capabilityIds.toSet();
  return capabilities.where((c) => ids.contains(c.id)).toList();
});

final serviceIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  serviceId,
) {
  final service = ref.watch(serviceByIdProvider(serviceId)).value;
  if (service == null) return const [];
  final industries = ref.watch(industriesStreamProvider).value ?? const [];
  final ids = service.industryIds.toSet();
  return industries.where((i) => ids.contains(i.id)).toList();
});

final serviceBusinessUnitsProvider =
    Provider.family<List<BusinessUnit>, String>((ref, serviceId) {
      final service = ref.watch(serviceByIdProvider(serviceId)).value;
      if (service == null) return const [];
      final units = ref.watch(businessUnitsStreamProvider).value ?? const [];
      final ids = service.businessUnitIds.toSet();
      return units.where((u) => ids.contains(u.id)).toList();
    });

final serviceKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, serviceId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all.where((a) => a.serviceIds.contains(serviceId)).toList();
    });

final serviceRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, serviceId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedServiceIds.isNotEmpty) {
          return r.relatedServiceIds.contains(serviceId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) => oppById[id]?.serviceIds.contains(serviceId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final serviceRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, serviceId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.serviceIds.contains(serviceId) ??
                false,
          )
          .toList();
    });

final serviceInsightsProvider = Provider.family<ServiceInsights, String>((
  ref,
  serviceId,
) {
  final opportunities = ref.watch(serviceOpportunitiesProvider(serviceId));
  final submissions = ref.watch(serviceSubmissionsProvider(serviceId));
  return deriveServiceInsights(
    opportunities: opportunities,
    submissions: submissions,
  );
});
