import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/match_analysis_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// A read-only AI insight report — unlike [OpportunityClassificationScreen],
/// nothing here is manually editable. Match analysis is re-run wholesale
/// (via "Run Match Analysis") rather than hand-corrected field by field;
/// see ADR-004 for why this screen intentionally diverges from the
/// classification screen's editable-form shape.
class OpportunityMatchAnalysisScreen extends ConsumerStatefulWidget {
  const OpportunityMatchAnalysisScreen({
    super.key,
    required this.opportunityId,
  });

  final String opportunityId;

  @override
  ConsumerState<OpportunityMatchAnalysisScreen> createState() =>
      _OpportunityMatchAnalysisScreenState();
}

class _OpportunityMatchAnalysisScreenState
    extends ConsumerState<OpportunityMatchAnalysisScreen> {
  bool _analyzing = false;

  Future<void> _runMatchAnalysis() async {
    setState(() => _analyzing = true);
    final strings = ref.read(appStringsProvider);
    try {
      await ref
          .read(matchAnalysisServiceProvider)
          .analyzeMatch(widget.opportunityId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.matchAnalysisSucceeded)));
      }
    } on MatchAnalysisException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.matchAnalysisFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
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
                      icon: Icons.insights_outlined,
                      title: strings.matchAnalysisScreenTitle,
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
              onPressed: _analyzing ? null : _runMatchAnalysis,
              icon: _analyzing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights_outlined, size: 18),
              label: Text(strings.runMatchAnalysisButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          opportunity.matchAnalyzedAt != null
              ? strings.lastMatchAnalysisLabel(
                  dateFormat.format(opportunity.matchAnalyzedAt!),
                )
              : strings.neverAnalyzedLabel,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (opportunity.overallMatchScore == null)
          Text(strings.noMatchAnalysisYet)
        else ...[
          SectionHeader(
            title: strings.overallMatchScoreLabel,
            accentColor: AppStatusColors.ai,
          ),
          Text(
            '${opportunity.overallMatchScore}%',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: strings.categoryBreakdownLabel,
            accentColor: AppStatusColors.ai,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _scoreChip(
                strings.businessUnitScoreLabel,
                opportunity.businessUnitScore,
              ),
              _scoreChip(strings.productScoreLabel, opportunity.productScore),
              _scoreChip(strings.serviceScoreLabel, opportunity.serviceScore),
              _scoreChip(
                strings.capabilityScoreLabel,
                opportunity.capabilityScore,
              ),
              _scoreChip(
                strings.technologyScoreLabel,
                opportunity.technologyScore,
              ),
              _scoreChip(strings.industryScoreLabel, opportunity.industryScore),
              _scoreChip(
                strings.experienceScoreLabel,
                opportunity.experienceScore,
              ),
              _scoreChip(
                strings.knowledgeScoreLabel,
                opportunity.knowledgeScore,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (opportunity.strategicRecommendation?.isNotEmpty ?? false) ...[
            SectionHeader(
              title: strings.strategicRecommendationLabel,
              accentColor: AppStatusColors.ai,
            ),
            Text(opportunity.strategicRecommendation!),
            const SizedBox(height: AppSpacing.xl),
          ],
          _bulletSection(
            context,
            strings.strengthsLabel,
            opportunity.strengths,
          ),
          _bulletSection(context, strings.gapsLabel, opportunity.gaps),
          _bulletSection(context, strings.risksLabel, opportunity.risks),
          _bulletSection(
            context,
            strings.nextActionsLabel,
            opportunity.nextActions,
          ),
          RecommendedEntityChips<Product>(
            label: strings.recommendedProductsLabel,
            ids: opportunity.recommendedProductIds,
            optionsAsync: ref.watch(productsStreamProvider),
            idOf: (p) => p.id,
            nameOf: (p) => p.name,
          ),
          RecommendedEntityChips<BusinessUnit>(
            label: strings.recommendedBusinessUnitsLabel,
            ids: opportunity.recommendedBusinessUnitIds,
            optionsAsync: ref.watch(businessUnitsStreamProvider),
            idOf: (u) => u.id,
            nameOf: (u) => u.name,
          ),
          RecommendedEntityChips<Experience>(
            label: strings.recommendedExperiencesLabel,
            ids: opportunity.recommendedExperienceIds,
            optionsAsync: ref.watch(experiencesStreamProvider),
            idOf: (e) => e.id,
            nameOf: (e) => e.title,
          ),
          RecommendedEntityChips<KnowledgeArticle>(
            label: strings.recommendedKnowledgeLabel,
            ids: opportunity.recommendedKnowledgeArticleIds,
            optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
            idOf: (a) => a.id,
            nameOf: (a) => a.title,
          ),
        ],
      ],
    );
  }

  Widget _scoreChip(String label, int? score) {
    if (score == null) return const SizedBox.shrink();
    return Chip(label: Text('$label: $score%'));
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
