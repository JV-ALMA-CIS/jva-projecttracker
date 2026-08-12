import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/priority_style.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';

IconData _categoryIcon(RecommendationCategory category) {
  return switch (category) {
    RecommendationCategory.priorityOpportunity => Icons.flag_outlined,
    RecommendationCategory.atRiskOpportunity => Icons.warning_amber_outlined,
    RecommendationCategory.capabilityGap => Icons.extension_outlined,
    RecommendationCategory.resourceAllocation => Icons.groups_outlined,
    RecommendationCategory.general => Icons.lightbulb_outline,
  };
}

/// A single AI recommendation, rendered consistently wherever it appears —
/// the Dashboard's compact top-3 section and the full `RecommendationsScreen`
/// both use this widget, only varying [compact] and which action callbacks
/// are supplied. See ADR-006.
///
/// [onDismiss]/[onMarkActioned] are left null to omit their buttons entirely
/// (the Dashboard's compact cards are tap-to-view-all, not actionable
/// in-place); the full screen supplies both.
class RecommendationCard extends ConsumerWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.compact = false,
    this.onTap,
    this.onDismiss,
    this.onMarkActioned,
  });

  final Recommendation recommendation;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onMarkActioned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final (priorityBg, priorityFg) = priorityColors(
      theme.colorScheme,
      recommendation.priority,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _categoryIcon(recommendation.category),
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      recommendation.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    label: Text(
                      strings.opportunityPriorityLabel(recommendation.priority),
                    ),
                    backgroundColor: priorityBg,
                    labelStyle: TextStyle(color: priorityFg),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      strings.recommendationCategoryLabel(
                        recommendation.category,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (recommendation.confidenceScore != null)
                    Chip(
                      label: Text(
                        strings.confidenceScoreChipLabel(
                          recommendation.confidenceScore!,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                recommendation.reasoning,
                style: theme.textTheme.bodyMedium,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
              ),
              if (!compact) ...[
                const SizedBox(height: AppSpacing.md),
                RecommendedEntityChips<Opportunity>(
                  label: strings.relatedOpportunitiesLabel,
                  ids: recommendation.relatedOpportunityIds,
                  optionsAsync: ref.watch(opportunitiesStreamProvider),
                  idOf: (o) => o.id,
                  nameOf: (o) => o.title,
                ),
                RecommendedEntityChips<BusinessUnit>(
                  label: strings.recommendedBusinessUnitsLabel,
                  ids: recommendation.relatedBusinessUnitIds,
                  optionsAsync: ref.watch(businessUnitsStreamProvider),
                  idOf: (u) => u.id,
                  nameOf: (u) => u.name,
                ),
                RecommendedEntityChips<Product>(
                  label: strings.recommendedProductsLabel,
                  ids: recommendation.relatedProductIds,
                  optionsAsync: ref.watch(productsStreamProvider),
                  idOf: (p) => p.id,
                  nameOf: (p) => p.name,
                ),
                RecommendedEntityChips<ServiceModel>(
                  label: strings.recommendedServicesLabel,
                  ids: recommendation.relatedServiceIds,
                  optionsAsync: ref.watch(servicesStreamProvider),
                  idOf: (s) => s.id,
                  nameOf: (s) => s.name,
                ),
                RecommendedEntityChips<Capability>(
                  label: strings.recommendedCapabilitiesLabel,
                  ids: recommendation.relatedCapabilityIds,
                  optionsAsync: ref.watch(capabilitiesStreamProvider),
                  idOf: (c) => c.id,
                  nameOf: (c) => c.name,
                ),
                RecommendedEntityChips<Technology>(
                  label: strings.recommendedTechnologiesLabel,
                  ids: recommendation.relatedTechnologyIds,
                  optionsAsync: ref.watch(technologiesStreamProvider),
                  idOf: (t) => t.id,
                  nameOf: (t) => t.name,
                ),
                RecommendedEntityChips<Industry>(
                  label: strings.recommendedIndustriesLabel,
                  ids: recommendation.relatedIndustryIds,
                  optionsAsync: ref.watch(industriesStreamProvider),
                  idOf: (i) => i.id,
                  nameOf: (i) => i.name,
                ),
                RecommendedEntityChips<Experience>(
                  label: strings.recommendedExperiencesLabel,
                  ids: recommendation.relatedExperienceIds,
                  optionsAsync: ref.watch(experiencesStreamProvider),
                  idOf: (e) => e.id,
                  nameOf: (e) => e.title,
                ),
                RecommendedEntityChips<KnowledgeArticle>(
                  label: strings.recommendedKnowledgeLabel,
                  ids: recommendation.relatedKnowledgeArticleIds,
                  optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
                  idOf: (a) => a.id,
                  nameOf: (a) => a.title,
                ),
                if (onDismiss != null || onMarkActioned != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        if (onDismiss != null)
                          TextButton.icon(
                            onPressed: onDismiss,
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(strings.dismissRecommendationTooltip),
                          ),
                        if (onMarkActioned != null)
                          FilledButton.icon(
                            onPressed: onMarkActioned,
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(strings.markActionedTooltip),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
