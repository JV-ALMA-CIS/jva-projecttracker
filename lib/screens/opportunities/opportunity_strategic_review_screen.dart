import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/strategic_review_service.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/strategic_decision_panel.dart';

/// A read-only executive-decision report — like
/// [OpportunityMatchAnalysisScreen], nothing here is manually editable.
/// Strategic review is re-run wholesale (via "Run Strategic Review") rather
/// than hand-corrected field by field; the brief itself asks for "read-only
/// recommendation chips, not editable relationship pickers," confirming
/// this screen follows the same read-only report shape as match analysis
/// rather than classification's editable-form shape. See ADR-005.
class OpportunityStrategicReviewScreen extends ConsumerStatefulWidget {
  const OpportunityStrategicReviewScreen({
    super.key,
    required this.opportunityId,
  });

  final String opportunityId;

  @override
  ConsumerState<OpportunityStrategicReviewScreen> createState() =>
      _OpportunityStrategicReviewScreenState();
}

class _OpportunityStrategicReviewScreenState
    extends ConsumerState<OpportunityStrategicReviewScreen> {
  bool _generating = false;

  Future<void> _runStrategicReview() async {
    setState(() => _generating = true);
    final strings = ref.read(appStringsProvider);
    try {
      await ref
          .read(strategicReviewServiceProvider)
          .generateReview(widget.opportunityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.strategicReviewSucceeded)),
        );
      }
    } on StrategicReviewException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.strategicReviewFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opportunityAsync = ref.watch(
      opportunityByIdProvider(widget.opportunityId),
    );
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(),
      body: opportunityAsync.when(
        data: (opportunity) => opportunity == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      icon: Icons.fact_check_outlined,
                      title: strings.strategicReviewScreenTitle,
                      accentColor: AppStatusColors.ai,
                    ),
                  ),
                  Expanded(child: _buildBody(context, strings, opportunity)),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppStrings strings,
    Opportunity opportunity,
  ) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _generating ? null : _runStrategicReview,
              icon: _generating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(strings.runStrategicReviewButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          opportunity.strategicReviewedAt != null
              ? strings.lastStrategicReviewLabel(
                  dateFormat.format(opportunity.strategicReviewedAt!),
                )
              : strings.neverReviewedStrategicallyLabel,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (opportunity.executiveSummary == null &&
            opportunity.executiveRecommendation == null)
          Text(strings.noStrategicReviewYet)
        else ...[
          SectionHeader(
            title: strings.aiRecommendationLabel,
            accentColor: AppStatusColors.ai,
          ),
          if (opportunity.executiveRecommendation != null)
            Chip(
              label: Text(
                strings.strategicReviewRecommendationLabel(
                  opportunity.executiveRecommendation!,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          StrategicDecisionPanel(opportunity: opportunity),
          const SizedBox(height: AppSpacing.lg),
          if (opportunity.executiveSummary?.isNotEmpty ?? false) ...[
            SectionHeader(
              title: strings.executiveSummaryLabel,
              accentColor: AppStatusColors.ai,
            ),
            Text(opportunity.executiveSummary!),
            const SizedBox(height: AppSpacing.xl),
          ],
          _bulletSection(
            context,
            strings.strategicStrengthsLabel,
            opportunity.strategicStrengths,
          ),
          _bulletSection(
            context,
            strings.strategicWeaknessesLabel,
            opportunity.strategicWeaknesses,
          ),
          _bulletSection(
            context,
            strings.strategicRisksLabel,
            opportunity.strategicRisks,
          ),
          _bulletSection(
            context,
            strings.mitigationStrategiesLabel,
            opportunity.mitigationStrategies,
          ),
          _bulletSection(
            context,
            strings.competitiveAdvantagesLabel,
            opportunity.competitiveAdvantages,
          ),
          _bulletSection(
            context,
            strings.missingRequirementsLabel,
            opportunity.missingRequirements,
          ),
          _bulletSection(
            context,
            strings.nextRecommendedActionsLabel,
            opportunity.nextRecommendedActions,
          ),
          RecommendedEntityChips<BusinessUnit>(
            label: strings.recommendedBusinessUnitsLabel,
            ids: opportunity.strategicReviewBusinessUnitIds,
            optionsAsync: ref.watch(businessUnitsStreamProvider),
            idOf: (u) => u.id,
            nameOf: (u) => u.name,
          ),
          RecommendedEntityChips<Product>(
            label: strings.recommendedProductsLabel,
            ids: opportunity.strategicReviewProductIds,
            optionsAsync: ref.watch(productsStreamProvider),
            idOf: (p) => p.id,
            nameOf: (p) => p.name,
          ),
          RecommendedEntityChips<ServiceModel>(
            label: strings.recommendedServicesLabel,
            ids: opportunity.strategicReviewServiceIds,
            optionsAsync: ref.watch(servicesStreamProvider),
            idOf: (s) => s.id,
            nameOf: (s) => s.name,
          ),
          RecommendedEntityChips<Capability>(
            label: strings.recommendedCapabilitiesLabel,
            ids: opportunity.strategicReviewCapabilityIds,
            optionsAsync: ref.watch(capabilitiesStreamProvider),
            idOf: (c) => c.id,
            nameOf: (c) => c.name,
          ),
          RecommendedEntityChips<Technology>(
            label: strings.recommendedTechnologiesLabel,
            ids: opportunity.strategicReviewTechnologyIds,
            optionsAsync: ref.watch(technologiesStreamProvider),
            idOf: (t) => t.id,
            nameOf: (t) => t.name,
          ),
          RecommendedEntityChips<Experience>(
            label: strings.recommendedExperiencesLabel,
            ids: opportunity.strategicReviewExperienceIds,
            optionsAsync: ref.watch(experiencesStreamProvider),
            idOf: (e) => e.id,
            nameOf: (e) => e.title,
          ),
          RecommendedEntityChips<KnowledgeArticle>(
            label: strings.recommendedKnowledgeLabel,
            ids: opportunity.strategicReviewKnowledgeArticleIds,
            optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
            idOf: (a) => a.id,
            nameOf: (a) => a.title,
          ),
          if (opportunity.proposalPositioningStrategy?.isNotEmpty ?? false) ...[
            SectionHeader(
              title: strings.proposalPositioningStrategyLabel,
              accentColor: AppStatusColors.ai,
            ),
            Text(opportunity.proposalPositioningStrategy!),
          ],
        ],
      ],
    );
  }

  Widget _bulletSection(
    BuildContext context,
    String label,
    List<String> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
