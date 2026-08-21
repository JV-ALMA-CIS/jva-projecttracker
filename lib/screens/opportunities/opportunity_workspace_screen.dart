import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/screens/company_intelligence/certifications/certifications_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_classification_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_pipeline_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/ai_classification_service.dart';
import 'package:jva_projecttracker/services/certification_eligibility.dart';
import 'package:jva_projecttracker/services/match_analysis_service.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/strategic_review_service.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/opportunity_timeline.dart';
import 'package:jva_projecttracker/widgets/pipeline_stage_badge.dart';
import 'package:jva_projecttracker/widgets/priority_style.dart';
import 'package:jva_projecttracker/widgets/proposal_progress_ring.dart';
import 'package:jva_projecttracker/widgets/recommendation_card.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/stage_transition_dialog.dart';
import 'package:jva_projecttracker/widgets/submission_status_style.dart';

/// The Opportunity Workspace — the single place a user works one
/// opportunity end to end, replacing the old "expand the list tile, pick
/// one of 5 menu items, each its own screen" flow. AI insight leads,
/// editable detail is secondary: every field the 4 older screens
/// (`OpportunityClassificationScreen`/`OpportunityMatchAnalysisScreen`/
/// `OpportunityStrategicReviewScreen`/`OpportunityPipelineScreen`) show
/// already lives on the same [Opportunity] document, so this screen reads
/// it directly rather than embedding or duplicating those screens' form
/// logic. Those 4 screens are unchanged and still exist as the "edit
/// details"/"run again" destinations reached from within each section here.
class OpportunityWorkspaceScreen extends ConsumerStatefulWidget {
  const OpportunityWorkspaceScreen({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  ConsumerState<OpportunityWorkspaceScreen> createState() =>
      _OpportunityWorkspaceScreenState();
}

class _OpportunityWorkspaceScreenState
    extends ConsumerState<OpportunityWorkspaceScreen> {
  bool _classifying = false;
  bool _analyzingMatch = false;
  bool _generatingReview = false;

  Future<void> _runClassification() async {
    setState(() => _classifying = true);
    final strings = ref.read(appStringsProvider);
    try {
      await ref
          .read(aiClassificationServiceProvider)
          .classifyOpportunity(widget.opportunityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiClassificationSucceeded)),
        );
      }
    } on AIClassificationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiClassificationFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  Future<void> _runMatchAnalysis() async {
    setState(() => _analyzingMatch = true);
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
      if (mounted) setState(() => _analyzingMatch = false);
    }
  }

  Future<void> _runStrategicReview() async {
    setState(() => _generatingReview = true);
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
      if (mounted) setState(() => _generatingReview = false);
    }
  }

  Future<void> _changeStage(Opportunity opportunity) async {
    final result = await showStageTransitionDialog(
      context,
      currentStage: opportunity.pipelineStage,
    );
    if (result == null) return;
    final actor = ref.read(authStateChangesProvider).value?.email;
    await ref
        .read(opportunityServiceProvider)
        .transitionStage(
          opportunityId: widget.opportunityId,
          newStage: result.stage,
          note: result.note,
          actor: actor,
        );
  }

  String _deadlineText(AppStrings strings, DateTime deadline) {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return strings.deadlineOverdueLabel(-daysLeft);
    if (daysLeft == 0) return strings.deadlineDueTodayLabel;
    return strings.deadlineDueInLabel(daysLeft);
  }

  Widget? _priorityChip(
    ThemeData theme,
    AppStrings strings,
    OpportunityPriority? priority,
  ) {
    if (priority == null) return null;
    final (bg, fg) = priorityColors(theme.colorScheme, priority);
    return Chip(
      label: Text(strings.opportunityPriorityLabel(priority)),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget? _riskChip(ThemeData theme, AppStrings strings, RiskLevel? risk) {
    if (risk == null) return null;
    final (bg, fg) = riskColors(theme.colorScheme, risk);
    return Chip(
      label: Text(strings.riskLevelLabel(risk)),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _scoreChip(String label, int? score) {
    if (score == null) return const SizedBox.shrink();
    return Chip(
      label: Text('$label: $score%'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _bulletList(BuildContext context, String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
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

  Widget _actionTile({
    required IconData icon,
    required String label,
    required bool loading,
    VoidCallback? onTap,
  }) {
    return HoverLift(
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (onTap != null ? const Icon(Icons.chevron_right) : null),
          onTap: loading ? null : onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final opportunityAsync = ref.watch(
      opportunityByIdProvider(widget.opportunityId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          opportunityAsync.value?.title ?? strings.opportunitiesTitle,
        ),
      ),
      body: opportunityAsync.when(
        data: (o) => o == null
            ? const SizedBox.shrink()
            : _buildBody(context, strings, o),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppStrings strings, Opportunity o) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();
    final proposalAsync = ref.watch(
      proposalByOpportunityIdProvider(widget.opportunityId),
    );
    final relatedRecommendations = ref.watch(
      recommendationsForOpportunityProvider(widget.opportunityId),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildHeader(context, strings, o),
        const SizedBox(height: AppSpacing.xl),
        _buildAiOverview(context, strings, o),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: strings.needsAttentionSectionTitle,
          accentColor: AppStatusColors.warning,
        ),
        _buildNeedsAttention(context, strings, o, proposalAsync.value),
        const SizedBox(height: AppSpacing.xl),
        _buildClassificationSection(context, strings, o, dateFormat),
        const SizedBox(height: AppSpacing.md),
        _BusinessUnitsSection(opportunity: o),
        const SizedBox(height: AppSpacing.md),
        _EligibilitySection(opportunity: o),
        const SizedBox(height: AppSpacing.md),
        _buildMatchAnalysisSection(context, strings, o, dateFormat),
        const SizedBox(height: AppSpacing.md),
        _buildStrategicReviewSection(context, strings, o, dateFormat),
        const SizedBox(height: AppSpacing.md),
        _buildPipelineSection(context, strings, o),
        const SizedBox(height: AppSpacing.md),
        _buildProposalSection(context, strings, proposalAsync),
        const SizedBox(height: AppSpacing.md),
        _buildSubmissionSection(context, strings, proposalAsync),
        if (_showsProjectSection(o.pipelineStage)) ...[
          const SizedBox(height: AppSpacing.md),
          _buildProjectSection(context, strings, o),
        ],
        if (relatedRecommendations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.aiRecommendationsSectionTitle,
            accentColor: AppStatusColors.ai,
          ),
          for (final r in relatedRecommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: RecommendationCard(
                recommendation: r,
                compact: true,
                onTap: () =>
                    pushSlideFade(context, const RecommendationsScreen()),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppStrings strings, Opportunity o) {
    final theme = Theme.of(context);
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FitScoreBadge(percent: o.fitScorePercent, size: 48),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.client ?? o.sourceUrl,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            PipelineStageBadge(stage: o.pipelineStage),
                            ?_priorityChip(theme, strings, o.priority),
                            ?_riskChip(theme, strings, o.riskLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (o.deadline != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _deadlineText(strings, o.deadline!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (o.assignedTo?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${strings.fieldAssignedTo}: ${o.assignedTo}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiOverview(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
  ) {
    final theme = Theme.of(context);
    String headline;
    String? body;
    if (o.strategicReviewedAt != null) {
      headline = o.executiveRecommendation != null
          ? strings.strategicReviewRecommendationLabel(
              o.executiveRecommendation!,
            )
          : strings.aiOverviewSectionTitle;
      body = o.executiveSummary;
    } else if (o.matchAnalyzedAt != null) {
      headline = o.overallMatchScore != null
          ? '${o.overallMatchScore}% ${strings.overallMatchScoreLabel}'
          : strings.aiOverviewSectionTitle;
      body = o.strategicRecommendation;
    } else {
      headline = strings.fitReasoningLabel;
      body = o.fitReasoning.isNotEmpty ? o.fitReasoning : null;
    }

    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppStatusColors.ai,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    strings.aiOverviewSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                headline,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(body),
              ],
              if (o.confidenceScore != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Chip(
                  label: Text(
                    strings.confidenceScoreChipLabel(o.confidenceScore!),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedsAttention(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
    Proposal? proposal,
  ) {
    final items = <Widget>[];

    if (o.aiReviewedAt == null) {
      items.add(
        _actionTile(
          icon: Icons.psychology_outlined,
          label: strings.runAiClassificationButton,
          loading: _classifying,
          onTap: _runClassification,
        ),
      );
    }
    if (o.matchAnalyzedAt == null) {
      items.add(
        _actionTile(
          icon: Icons.insights_outlined,
          label: strings.runMatchAnalysisButton,
          loading: _analyzingMatch,
          onTap: _runMatchAnalysis,
        ),
      );
    }
    if (o.strategicReviewedAt == null) {
      items.add(
        _actionTile(
          icon: Icons.fact_check_outlined,
          label: strings.runStrategicReviewButton,
          loading: _generatingReview,
          onTap: _runStrategicReview,
        ),
      );
    }
    if (o.pipelineStage.index >= OpportunityPipelineStage.approved.index &&
        proposal == null) {
      items.add(
        _actionTile(
          icon: Icons.description_outlined,
          label: strings.proposalTooltip,
          loading: false,
          onTap: () => pushSlideFade(
            context,
            ProposalWorkspaceScreen(opportunityId: widget.opportunityId),
          ),
        ),
      );
    }
    if (o.deadline != null) {
      final daysLeft = o.deadline!.difference(DateTime.now()).inDays;
      if (daysLeft <= kDeadlineWindowDays) {
        items.add(
          _actionTile(
            icon: Icons.schedule_outlined,
            label: _deadlineText(strings, o.deadline!),
            loading: false,
          ),
        );
      }
    }

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: strings.noUrgentAlerts,
        compact: true,
      );
    }
    return Column(children: items);
  }

  Widget _buildClassificationSection(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.psychology_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(strings.sectionClassification),
        subtitle: Text(
          (o.classificationSummary?.isNotEmpty ?? false)
              ? o.classificationSummary!
              : strings.classificationStatusLabel(o.classificationStatus),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _classifying ? null : _runClassification,
                      icon: _classifying
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(strings.runAiClassificationButton),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pushSlideFade(
                        context,
                        OpportunityClassificationScreen(
                          opportunityId: widget.opportunityId,
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(strings.editClassificationTooltip),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  o.aiReviewedAt != null
                      ? strings.lastAiReviewLabel(
                          dateFormat.format(o.aiReviewedAt!),
                        )
                      : strings.neverReviewedByAiLabel,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ?_priorityChip(theme, strings, o.priority),
                    ?_riskChip(theme, strings, o.riskLevel),
                    if (o.estimatedComplexity != null)
                      Chip(
                        label: Text(
                          strings.estimatedComplexityLabel(
                            o.estimatedComplexity!,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (o.opportunityType?.isNotEmpty ?? false)
                      Chip(
                        label: Text(o.opportunityType!),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (o.confidenceScore != null)
                      Chip(
                        label: Text(
                          strings.confidenceScoreChipLabel(o.confidenceScore!),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchAnalysisSection(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.insights_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(strings.matchAnalysisScreenTitle),
        subtitle: Text(
          o.overallMatchScore != null
              ? '${o.overallMatchScore}%'
                    '${(o.strategicRecommendation?.isNotEmpty ?? false) ? ' · ${o.strategicRecommendation}' : ''}'
              : strings.noMatchAnalysisYet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _analyzingMatch ? null : _runMatchAnalysis,
                  icon: _analyzingMatch
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.insights_outlined, size: 18),
                  label: Text(strings.runMatchAnalysisButton),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  o.matchAnalyzedAt != null
                      ? strings.lastMatchAnalysisLabel(
                          dateFormat.format(o.matchAnalyzedAt!),
                        )
                      : strings.neverAnalyzedLabel,
                  style: theme.textTheme.bodySmall,
                ),
                if (o.overallMatchScore != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _scoreChip(
                        strings.businessUnitScoreLabel,
                        o.businessUnitScore,
                      ),
                      _scoreChip(strings.productScoreLabel, o.productScore),
                      _scoreChip(strings.serviceScoreLabel, o.serviceScore),
                      _scoreChip(
                        strings.capabilityScoreLabel,
                        o.capabilityScore,
                      ),
                      _scoreChip(
                        strings.technologyScoreLabel,
                        o.technologyScore,
                      ),
                      _scoreChip(strings.industryScoreLabel, o.industryScore),
                      _scoreChip(
                        strings.experienceScoreLabel,
                        o.experienceScore,
                      ),
                      _scoreChip(strings.knowledgeScoreLabel, o.knowledgeScore),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _bulletList(context, strings.strengthsLabel, o.strengths),
                  _bulletList(context, strings.gapsLabel, o.gaps),
                  _bulletList(context, strings.risksLabel, o.risks),
                  _bulletList(context, strings.nextActionsLabel, o.nextActions),
                  RecommendedEntityChips<Product>(
                    label: strings.recommendedProductsLabel,
                    ids: o.recommendedProductIds,
                    optionsAsync: ref.watch(productsStreamProvider),
                    idOf: (p) => p.id,
                    nameOf: (p) => p.name,
                  ),
                  RecommendedEntityChips<BusinessUnit>(
                    label: strings.recommendedBusinessUnitsLabel,
                    ids: o.recommendedBusinessUnitIds,
                    optionsAsync: ref.watch(businessUnitsStreamProvider),
                    idOf: (u) => u.id,
                    nameOf: (u) => u.name,
                  ),
                  RecommendedEntityChips<Experience>(
                    label: strings.recommendedExperiencesLabel,
                    ids: o.recommendedExperienceIds,
                    optionsAsync: ref.watch(experiencesStreamProvider),
                    idOf: (e) => e.id,
                    nameOf: (e) => e.title,
                  ),
                  RecommendedEntityChips<KnowledgeArticle>(
                    label: strings.recommendedKnowledgeLabel,
                    ids: o.recommendedKnowledgeArticleIds,
                    optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
                    idOf: (a) => a.id,
                    nameOf: (a) => a.title,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicReviewSection(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.fact_check_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(strings.strategicReviewScreenTitle),
        subtitle: Text(
          o.executiveRecommendation != null
              ? strings.strategicReviewRecommendationLabel(
                  o.executiveRecommendation!,
                )
              : strings.noStrategicReviewYet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _generatingReview ? null : _runStrategicReview,
                  icon: _generatingReview
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(strings.runStrategicReviewButton),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  o.strategicReviewedAt != null
                      ? strings.lastStrategicReviewLabel(
                          dateFormat.format(o.strategicReviewedAt!),
                        )
                      : strings.neverReviewedStrategicallyLabel,
                  style: theme.textTheme.bodySmall,
                ),
                if (o.executiveSummary != null ||
                    o.executiveRecommendation != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (o.executiveSummary?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(o.executiveSummary!),
                    ),
                  _bulletList(
                    context,
                    strings.strategicStrengthsLabel,
                    o.strategicStrengths,
                  ),
                  _bulletList(
                    context,
                    strings.strategicWeaknessesLabel,
                    o.strategicWeaknesses,
                  ),
                  _bulletList(
                    context,
                    strings.strategicRisksLabel,
                    o.strategicRisks,
                  ),
                  _bulletList(
                    context,
                    strings.mitigationStrategiesLabel,
                    o.mitigationStrategies,
                  ),
                  _bulletList(
                    context,
                    strings.competitiveAdvantagesLabel,
                    o.competitiveAdvantages,
                  ),
                  _bulletList(
                    context,
                    strings.missingRequirementsLabel,
                    o.missingRequirements,
                  ),
                  _bulletList(
                    context,
                    strings.nextRecommendedActionsLabel,
                    o.nextRecommendedActions,
                  ),
                  RecommendedEntityChips<BusinessUnit>(
                    label: strings.recommendedBusinessUnitsLabel,
                    ids: o.strategicReviewBusinessUnitIds,
                    optionsAsync: ref.watch(businessUnitsStreamProvider),
                    idOf: (u) => u.id,
                    nameOf: (u) => u.name,
                  ),
                  RecommendedEntityChips<Product>(
                    label: strings.recommendedProductsLabel,
                    ids: o.strategicReviewProductIds,
                    optionsAsync: ref.watch(productsStreamProvider),
                    idOf: (p) => p.id,
                    nameOf: (p) => p.name,
                  ),
                  RecommendedEntityChips<ServiceModel>(
                    label: strings.recommendedServicesLabel,
                    ids: o.strategicReviewServiceIds,
                    optionsAsync: ref.watch(servicesStreamProvider),
                    idOf: (s) => s.id,
                    nameOf: (s) => s.name,
                  ),
                  RecommendedEntityChips<Capability>(
                    label: strings.recommendedCapabilitiesLabel,
                    ids: o.strategicReviewCapabilityIds,
                    optionsAsync: ref.watch(capabilitiesStreamProvider),
                    idOf: (c) => c.id,
                    nameOf: (c) => c.name,
                  ),
                  RecommendedEntityChips<Technology>(
                    label: strings.recommendedTechnologiesLabel,
                    ids: o.strategicReviewTechnologyIds,
                    optionsAsync: ref.watch(technologiesStreamProvider),
                    idOf: (t) => t.id,
                    nameOf: (t) => t.name,
                  ),
                  RecommendedEntityChips<Experience>(
                    label: strings.recommendedExperiencesLabel,
                    ids: o.strategicReviewExperienceIds,
                    optionsAsync: ref.watch(experiencesStreamProvider),
                    idOf: (e) => e.id,
                    nameOf: (e) => e.title,
                  ),
                  RecommendedEntityChips<KnowledgeArticle>(
                    label: strings.recommendedKnowledgeLabel,
                    ids: o.strategicReviewKnowledgeArticleIds,
                    optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
                    idOf: (a) => a.id,
                    nameOf: (a) => a.title,
                  ),
                  if (o.proposalPositioningStrategy?.isNotEmpty ?? false) ...[
                    Text(
                      strings.proposalPositioningStrategyLabel,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(o.proposalPositioningStrategy!),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineSection(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.timeline_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(strings.pipelineHistoryTitle),
        subtitle: PipelineStageBadge(stage: o.pipelineStage),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _changeStage(o),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(strings.changeStageButton),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pushSlideFade(
                        context,
                        OpportunityPipelineScreen(
                          opportunityId: widget.opportunityId,
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(strings.pipelineTooltip),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OpportunityTimeline(opportunityId: widget.opportunityId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalSection(
    BuildContext context,
    AppStrings strings,
    AsyncValue<Proposal?> proposalAsync,
  ) {
    return Card(
      child: proposalAsync.when(
        data: (proposal) {
          final progress = proposal == null
              ? 0.0
              : ref.watch(proposalSectionProgressProvider(proposal.id));
          return ListTile(
            leading: ProposalProgressRing(progress: progress, size: 40),
            title: Text(strings.proposalWorkspaceTitle),
            subtitle: Text(
              proposal == null ? strings.noActiveProposals : proposal.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushSlideFade(
              context,
              ProposalWorkspaceScreen(opportunityId: widget.opportunityId),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(strings.errorPrefix(e)),
        ),
      ),
    );
  }

  Widget _buildSubmissionSection(
    BuildContext context,
    AppStrings strings,
    AsyncValue<Proposal?> proposalAsync,
  ) {
    final proposal = proposalAsync.value;
    final submissionAsync = proposal == null
        ? const AsyncValue<Submission?>.data(null)
        : ref.watch(submissionByOpportunityIdProvider(widget.opportunityId));

    return Card(
      child: submissionAsync.when(
        data: (submission) {
          final statusColor = submission == null
              ? AppStatusColors.neutral
              : submissionStatusColor(submission.status);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.send_outlined, color: statusColor, size: 20),
            ),
            title: Text(strings.submissionWorkspaceTitle),
            subtitle: Text(
              submission == null
                  ? strings.createSubmissionEmptyStateTitle
                  : strings.submissionStatusLabel(submission.status),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushSlideFade(
              context,
              SubmissionWorkspaceScreen(opportunityId: widget.opportunityId),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(strings.errorPrefix(e)),
        ),
      ),
    );
  }

  /// Only `awarded`/`projectStarted`/`completed` — an explicit enum check,
  /// not an index comparison: `lost` sits numerically between `awarded` and
  /// `projectStarted` in `OpportunityPipelineStage`'s declared order and
  /// must never show a "start a project" prompt.
  bool _showsProjectSection(OpportunityPipelineStage stage) {
    return stage == OpportunityPipelineStage.awarded ||
        stage == OpportunityPipelineStage.projectStarted ||
        stage == OpportunityPipelineStage.completed;
  }

  Color _projectStatusColor(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => AppStatusColors.info,
    ProjectStatus.running => AppStatusColors.operations,
    ProjectStatus.past => AppStatusColors.neutral,
  };

  Widget _buildProjectSection(
    BuildContext context,
    AppStrings strings,
    Opportunity o,
  ) {
    final projectAsync = ref.watch(
      projectByOpportunityIdProvider(widget.opportunityId),
    );

    return Card(
      child: projectAsync.when(
        data: (project) {
          if (project == null) {
            return ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(strings.startProjectButton),
              subtitle: Text(
                strings.noProjectYetPrompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushSlideFade(
                context,
                ProjectFormScreen(
                  sourceOpportunityId: o.id,
                  initialName: o.title,
                  initialClient: o.client,
                  initialDescription: o.description,
                ),
              ),
            );
          }
          return ListTile(
            leading: Icon(
              Icons.construction_outlined,
              color: _projectStatusColor(project.status),
            ),
            title: Text(strings.projectSectionTitle),
            subtitle: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushSlideFade(
              context,
              ProjectWorkspaceScreen(projectId: project.id),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(strings.errorPrefix(e)),
        ),
      ),
    );
  }
}

/// The always-available manual correction tool for `Opportunity.businessUnitIds`
/// (Business Workflow Governance — BU backfill). Writes immediately on
/// toggle via [OpportunityService.updateBusinessUnitIds], the same pattern
/// the Submission Workspace's inline status control and other narrow
/// single-field editors in this app already use — no separate "Save"
/// button, no buffered local copy that could drift from what's actually
/// persisted. This is deliberately a human, explicit action: it always
/// wins over whatever `classifyOpportunity` last wrote (see that
/// function's empty-only guard in `functions/index.js`) and never invents
/// a new Business Unit — only existing `businessUnitsStreamProvider`
/// entries are offered, exactly like every other `RelationshipPicker` use
/// in this app.
class _BusinessUnitsSection extends ConsumerWidget {
  const _BusinessUnitsSection({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final businessUnitsAsync = ref.watch(businessUnitsStreamProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RelationshipPicker<BusinessUnit>(
              label: strings.businessUnitsSectionLabel,
              optionsAsync: businessUnitsAsync,
              idOf: (b) => b.id,
              nameOf: (b) => b.name,
              selectedIds: opportunity.businessUnitIds.toSet(),
              onToggle: (id, selected) {
                final updated = opportunity.businessUnitIds.toSet();
                if (selected) {
                  updated.add(id);
                } else {
                  updated.remove(id);
                }
                ref
                    .read(opportunityServiceProvider)
                    .updateBusinessUnitIds(opportunity.id, updated.toList());
              },
            ),
            if (opportunity.businessUnitIds.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.noBusinessUnitsAssignedMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Manual eligibility-requirements editor + computed gap display for the
/// Opportunity Workspace (Company Certifications, B4). Requirements are
/// always hand-entered — see [OpportunityCertificationRequirement]'s doc
/// comment — so this section never blocks on AI classification the way
/// [_buildMatchAnalysisSection]/[_buildStrategicReviewSection] do. Gaps are
/// recomputed live from [certificationsStreamProvider] via the pure
/// [computeEligibilityGaps] engine every time either the requirements list
/// or the held certifications change.
class _EligibilitySection extends ConsumerWidget {
  const _EligibilitySection({required this.opportunity});

  final Opportunity opportunity;

  Future<void> _addRequirement(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final result = await showDialog<OpportunityCertificationRequirement>(
      context: context,
      builder: (context) => _RequirementDialog(strings: strings),
    );
    if (result == null) return;
    final updated = [...opportunity.requiredCertifications, result];
    await ref
        .read(opportunityServiceProvider)
        .updateRequiredCertifications(opportunity.id, updated);
  }

  Future<void> _removeRequirement(WidgetRef ref, int index) async {
    final updated = [...opportunity.requiredCertifications]..removeAt(index);
    await ref
        .read(opportunityServiceProvider)
        .updateRequiredCertifications(opportunity.id, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = ref.watch(appStringsProvider);
    final certificationsAsync = ref.watch(certificationsStreamProvider);
    final requirements = opportunity.requiredCertifications;

    final gaps = computeEligibilityGaps(
      requirements: requirements,
      heldCertifications: certificationsAsync.value ?? const [],
      now: DateTime.now(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    strings.eligibilitySectionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      pushSlideFade(context, const CertificationsScreen()),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(strings.viewCertificationsButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              strings.eligibilitySectionCaption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (requirements.isEmpty)
              Text(
                strings.noRequirementsRecordedMessage,
                style: theme.textTheme.bodySmall,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < requirements.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(child: Text(requirements[i].label)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: strings.removeRequirementTooltip,
                            onPressed: () => _removeRequirement(ref, i),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (requirements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              if (gaps.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppStatusColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(strings.noEligibilityGapsMessage),
                  ],
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final gap in gaps)
                      Tooltip(
                        message: gap.detail,
                        child: Chip(
                          avatar: Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: gap.severity == EligibilityGapSeverity.danger
                                ? AppStatusColors.danger
                                : AppStatusColors.warning,
                          ),
                          label: Text(gap.label),
                          backgroundColor:
                              (gap.severity == EligibilityGapSeverity.danger
                                      ? AppStatusColors.danger
                                      : AppStatusColors.warning)
                                  .withValues(alpha: 0.12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _addRequirement(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(strings.addRequirementButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for manually adding one [OpportunityCertificationRequirement] —
/// type is required, grade/class is optional (non-NCA requirements can
/// match by type alone; see `certification_eligibility.dart`).
class _RequirementDialog extends StatefulWidget {
  const _RequirementDialog({required this.strings});

  final AppStrings strings;

  @override
  State<_RequirementDialog> createState() => _RequirementDialogState();
}

class _RequirementDialogState extends State<_RequirementDialog> {
  CertificationType _type = CertificationType.nca;
  final _gradeController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _gradeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.addRequirementButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<CertificationType>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: strings.fieldCertificationType,
            ),
            items: [
              for (final type in CertificationType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(strings.certificationTypeLabel(type)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _gradeController,
            decoration: InputDecoration(
              labelText: strings.requiredGradeOptionalHint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: strings.fieldCertificationName,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: () {
            final grade = _gradeController.text.trim();
            final label = _labelController.text.trim().isNotEmpty
                ? _labelController.text.trim()
                : strings.certificationTypeLabel(_type);
            Navigator.of(context).pop(
              OpportunityCertificationRequirement(
                type: _type,
                gradeOrClass: grade.isEmpty ? null : grade,
                label: label,
              ),
            );
          },
          child: Text(strings.saveButton),
        ),
      ],
    );
  }
}
