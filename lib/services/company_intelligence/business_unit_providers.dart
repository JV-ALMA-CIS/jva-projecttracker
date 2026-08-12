import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/business_unit_insights.dart';
import 'package:jva_projecttracker/services/business_unit_summary_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';

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

final businessUnitServiceProvider = Provider((ref) => BusinessUnitService());
final businessUnitSummaryServiceProvider = Provider(
  (ref) => BusinessUnitSummaryService(),
);

final businessUnitsStreamProvider = StreamProvider<List<BusinessUnit>>((ref) {
  return ref.watch(businessUnitServiceProvider).watchAll();
});

final businessUnitByIdProvider = StreamProvider.autoDispose
    .family<BusinessUnit?, String>((ref, id) {
      return ref.watch(businessUnitServiceProvider).watchById(id);
    });

/// Business-unit scoped derived providers. These are computed client-side
/// by filtering the global streams already loaded elsewhere in the app so
/// the Business Unit Workspace can show sections without additional reads.
final businessUnitOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>((ref, businessUnitId) {
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return all
          .where((o) => o.businessUnitIds.contains(businessUnitId))
          .toList();
    });

final businessUnitProposalsProvider = Provider.family<List<Proposal>, String>((
  ref,
  businessUnitId,
) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  final oppById = {for (final o in opportunities) o.id: o};
  return proposals
      .where(
        (p) =>
            oppById[p.opportunityId]?.businessUnitIds.contains(
              businessUnitId,
            ) ??
            false,
      )
      .toList();
});

final businessUnitSubmissionsProvider =
    Provider.family<List<Submission>, String>((ref, businessUnitId) {
      final submissions =
          ref.watch(submissionsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return submissions
          .where(
            (s) =>
                oppById[s.opportunityId]?.businessUnitIds.contains(
                  businessUnitId,
                ) ??
                false,
          )
          .toList();
    });

final businessUnitAwardedProjectsProvider =
    Provider.family<List<Project>, String>((ref, businessUnitId) {
      final projects = ref.watch(projectsStreamProvider).value ?? const [];
      return projects
          .where((p) => p.businessUnitIds.contains(businessUnitId))
          .toList();
    });

final businessUnitCapabilitiesProvider =
    Provider.family<List<Capability>, String>((ref, businessUnitId) {
      final unit = ref.watch(businessUnitByIdProvider(businessUnitId)).value;
      if (unit == null) return const [];
      final capabilities =
          ref.watch(capabilitiesStreamProvider).value ?? const [];
      final ids = unit.capabilityIds.toSet();
      return capabilities.where((c) => ids.contains(c.id)).toList();
    });

final businessUnitTechnologiesProvider =
    Provider.family<List<Technology>, String>((ref, businessUnitId) {
      final unit = ref.watch(businessUnitByIdProvider(businessUnitId)).value;
      if (unit == null) return const [];
      final technologies =
          ref.watch(technologiesStreamProvider).value ?? const [];
      final ids = unit.technologyIds.toSet();
      return technologies.where((t) => ids.contains(t.id)).toList();
    });

final businessUnitIndustriesProvider = Provider.family<List<Industry>, String>((
  ref,
  businessUnitId,
) {
  final unit = ref.watch(businessUnitByIdProvider(businessUnitId)).value;
  if (unit == null) return const [];
  final industries = ref.watch(industriesStreamProvider).value ?? const [];
  final ids = unit.industryIds.toSet();
  return industries.where((i) => ids.contains(i.id)).toList();
});

final businessUnitExperiencesProvider =
    Provider.family<List<Experience>, String>((ref, businessUnitId) {
      final experiences =
          ref.watch(experiencesStreamProvider).value ?? const [];
      return experiences
          .where((e) => e.businessUnitIds.contains(businessUnitId))
          .toList();
    });

final businessUnitKnowledgeArticlesProvider =
    Provider.family<List<KnowledgeArticle>, String>((ref, businessUnitId) {
      final all = ref.watch(knowledgeArticlesStreamProvider).value ?? const [];
      return all
          .where((a) => a.businessUnitIds.contains(businessUnitId))
          .toList();
    });

final businessUnitRecommendationsProvider =
    Provider.family<List<Recommendation>, String>((ref, businessUnitId) {
      final recs = ref.watch(recommendationsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return recs.where((r) {
        if (r.relatedBusinessUnitIds.isNotEmpty) {
          return r.relatedBusinessUnitIds.contains(businessUnitId);
        }
        if (r.relatedOpportunityIds.isNotEmpty) {
          return r.relatedOpportunityIds.any(
            (id) =>
                oppById[id]?.businessUnitIds.contains(businessUnitId) ?? false,
          );
        }
        return false;
      }).toList();
    });

final businessUnitRecentEventsProvider =
    Provider.family<List<OpportunityEvent>, String>((ref, businessUnitId) {
      final events =
          ref.watch(recentOpportunityEventsProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      return events
          .where(
            (e) =>
                oppById[e.opportunityId]?.businessUnitIds.contains(
                  businessUnitId,
                ) ??
                false,
          )
          .toList();
    });

final businessUnitInsightsProvider =
    Provider.family<BusinessUnitInsights, String>((ref, businessUnitId) {
      final opportunities = ref.watch(
        businessUnitOpportunitiesProvider(businessUnitId),
      );
      final submissions = ref.watch(
        businessUnitSubmissionsProvider(businessUnitId),
      );
      return deriveBusinessUnitInsights(
        opportunities: opportunities,
        submissions: submissions,
      );
    });
