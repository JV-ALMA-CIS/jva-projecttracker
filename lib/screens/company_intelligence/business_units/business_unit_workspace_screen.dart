import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_unit_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capability_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industry_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_article_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/product_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/service_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technology_workspace_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/business_unit_insights.dart';
import 'package:jva_projecttracker/services/business_unit_summary_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/pipeline_stage_badge.dart';
import 'package:jva_projecttracker/widgets/recommendation_card.dart';
import 'package:jva_projecttracker/widgets/related_entity_section.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/stat_card.dart';
import 'package:jva_projecttracker/widgets/stat_card_row.dart';
import 'package:jva_projecttracker/widgets/submission_status_style.dart';

/// The Business Unit Workspace — the first Company Intelligence-side screen
/// to adopt the "workspace" pattern already established by
/// `OpportunityWorkspaceScreen`: an executive summary + KPI header, AI
/// insight given top billing, then one section per linked entity (active
/// opportunities, proposal pipeline, submissions, awarded projects, related
/// products/services/capabilities/technologies/industries/experiences/
/// knowledge articles, AI recommendations, recent activity). Every section
/// is derived client-side from streams already loaded elsewhere in the app
/// (see the `businessUnit*Provider` family in `providers.dart` and
/// `business_unit_insights.dart`) — no new Firestore queries beyond the
/// Submission Workspace integration's `submissionsStreamProvider`, so no new
/// composite indexes. Sections with nothing to show are omitted rather than
/// rendered as empty placeholders, per the "avoid empty states/placeholder
/// cards" design rule.
class BusinessUnitWorkspaceScreen extends ConsumerWidget {
  const BusinessUnitWorkspaceScreen({super.key, required this.businessUnitId});

  final String businessUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final businessUnitAsync = ref.watch(
      businessUnitByIdProvider(businessUnitId),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: PageHeader(
                leading: PageBackButton(),
                title: strings.businessUnitsTitle,
                action: IconButton(
                  onPressed: () => pushSlideFade(
                    context,
                    BusinessUnitFormScreen(businessUnitId: businessUnitId),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: strings.editButton,
                ),
              ),
            ),
            Expanded(
              child: businessUnitAsync.when(
                data: (unit) => unit == null
                    ? const SizedBox.shrink()
                    : _Body(businessUnit: unit),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text(strings.errorPrefix(error))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.businessUnit});

  final BusinessUnit businessUnit;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _generatingSummary = false;

  Future<void> _generateSummary(String businessUnitId) async {
    final strings = ref.read(appStringsProvider);
    setState(() => _generatingSummary = true);
    try {
      await ref
          .read(businessUnitSummaryServiceProvider)
          .generateSummary(businessUnitId: businessUnitId);
    } on BusinessUnitSummaryException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.aiSummaryFailedMessage)));
      }
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  BusinessUnit get businessUnit => widget.businessUnit;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final id = businessUnit.id;

    final opportunities = ref.watch(businessUnitOpportunitiesProvider(id));
    final proposals = ref.watch(businessUnitProposalsProvider(id));
    final submissions = ref.watch(businessUnitSubmissionsProvider(id));
    final projects = ref.watch(businessUnitAwardedProjectsProvider(id));
    final products =
        ref.watch(productsByBusinessUnitProvider(id)).value ?? const [];
    final services =
        ref.watch(servicesByBusinessUnitProvider(id)).value ?? const [];
    final capabilities = ref.watch(businessUnitCapabilitiesProvider(id));
    final technologies = ref.watch(businessUnitTechnologiesProvider(id));
    final industries = ref.watch(businessUnitIndustriesProvider(id));
    final experiences = ref.watch(businessUnitExperiencesProvider(id));
    final knowledgeArticles = ref.watch(
      businessUnitKnowledgeArticlesProvider(id),
    );
    final recommendations = ref.watch(businessUnitRecommendationsProvider(id));
    final recentEvents = ref.watch(businessUnitRecentEventsProvider(id));
    final insights = ref.watch(businessUnitInsightsProvider(id));

    final hasAnyData =
        opportunities.isNotEmpty ||
        products.isNotEmpty ||
        services.isNotEmpty ||
        capabilities.isNotEmpty ||
        technologies.isNotEmpty ||
        industries.isNotEmpty ||
        experiences.isNotEmpty ||
        knowledgeArticles.isNotEmpty;

    final activeOpportunities = opportunities
        .where(
          (o) =>
              o.pipelineStage != OpportunityPipelineStage.lost &&
              o.pipelineStage != OpportunityPipelineStage.completed,
        )
        .toList();
    final activeProjects = projects
        .where(
          (p) =>
              p.status == ProjectStatus.running ||
              p.status == ProjectStatus.planned,
        )
        .toList();
    final completedProjects = projects
        .where((p) => p.status == ProjectStatus.past)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildHeader(context, theme, strings),
        const SizedBox(height: AppSpacing.xl),
        _buildKpis(context, theme, strings, insights),
        const SizedBox(height: AppSpacing.xl),
        _buildAiExpertiseSummary(context, theme, strings),
        const SizedBox(height: AppSpacing.xl),
        _buildAiInsight(context, theme, strings, insights),
        if (!hasAnyData) ...[
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            icon: Icons.hub_outlined,
            title: strings.noBusinessUnitDataMessage,
          ),
        ],
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.aiRecommendationsSectionTitle,
            accentColor: AppStatusColors.ai,
          ),
          for (final r in recommendations)
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
        if (activeOpportunities.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.activeOpportunitiesSectionTitle,
            accentColor: AppStatusColors.info,
          ),
          _buildOpportunities(context, activeOpportunities),
        ],
        if (proposals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.proposalPipelineSectionTitle,
            accentColor: AppStatusColors.info,
          ),
          _buildProposals(context, strings, ref, proposals),
        ],
        if (submissions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.submissionsSectionTitle,
            accentColor: AppStatusColors.info,
          ),
          _buildSubmissions(context, strings, submissions, opportunities),
        ],
        if (activeProjects.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.activeProjectsSectionTitle,
            accentColor: AppStatusColors.operations,
          ),
          _buildProjects(context, activeProjects),
        ],
        if (completedProjects.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.completedProjectsSectionTitle,
            accentColor: AppStatusColors.operations,
          ),
          _buildProjects(context, completedProjects),
        ],
        if (recentEvents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.recentActivitySectionTitle,
            accentColor: AppStatusColors.neutral,
          ),
          _buildActivity(context, strings, recentEvents),
        ],
        const SizedBox(height: AppSpacing.xl),
        RelatedEntitySection<Product>(
          title: strings.productsTitle,
          items: products,
          nameOf: (p) => p.name,
          accentColor: AppEntityColors.product,
          onTap: (p) => pushSlideFade(
            context,
            ProductWorkspaceScreen(productId: p.id),
          ),
        ),
        RelatedEntitySection<ServiceModel>(
          title: strings.servicesTitle,
          items: services,
          nameOf: (s) => s.name,
          accentColor: AppEntityColors.service,
          onTap: (s) => pushSlideFade(
            context,
            ServiceWorkspaceScreen(serviceId: s.id),
          ),
        ),
        RelatedEntitySection<Capability>(
          title: strings.capabilitiesTitle,
          items: capabilities,
          nameOf: (c) => c.name,
          accentColor: AppEntityColors.capability,
          onTap: (c) => pushSlideFade(
            context,
            CapabilityWorkspaceScreen(capabilityId: c.id),
          ),
        ),
        RelatedEntitySection<Technology>(
          title: strings.technologiesTitle,
          items: technologies,
          nameOf: (t) => t.name,
          accentColor: AppEntityColors.technology,
          onTap: (t) => pushSlideFade(
            context,
            TechnologyWorkspaceScreen(technologyId: t.id),
          ),
        ),
        RelatedEntitySection<Industry>(
          title: strings.industriesTitle,
          items: industries,
          nameOf: (i) => i.name,
          accentColor: AppEntityColors.industry,
          onTap: (i) => pushSlideFade(
            context,
            IndustryWorkspaceScreen(industryId: i.id),
          ),
        ),
        RelatedEntitySection<Experience>(
          title: strings.experiencesTitle,
          items: experiences,
          nameOf: (e) => e.title,
          accentColor: AppEntityColors.experience,
          onTap: (e) => pushSlideFade(
            context,
            ExperienceWorkspaceScreen(experienceId: e.id),
          ),
        ),
        RelatedEntitySection<KnowledgeArticle>(
          title: strings.knowledgeBaseTitle,
          items: knowledgeArticles,
          nameOf: (a) => a.title,
          accentColor: AppEntityColors.knowledgeBase,
          onTap: (a) => pushSlideFade(
            context,
            KnowledgeArticleWorkspaceScreen(articleId: a.id),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    businessUnit.name,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(businessUnit.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (businessUnit.summary.isNotEmpty ||
                businessUnit.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                businessUnit.summary.isNotEmpty
                    ? businessUnit.summary
                    : businessUnit.description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpis(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
    BusinessUnitInsights insights,
  ) {
    final winRate = insights.winRate;
    return StatCardRow(
      children: [
        StatCard(
          icon: Icons.travel_explore_outlined,
          label: strings.activeOpportunitiesLabel,
          value: '${insights.activeOpportunityCount}',
        ),
        StatCard(
          icon: Icons.emoji_events_outlined,
          label: strings.winRateLabel,
          value: winRate == null
              ? strings.noWinRateYetLabel
              : '${(winRate * 100).round()}%',
        ),
        StatCard(
          icon: Icons.send_outlined,
          label: strings.openSubmissionsLabel,
          value: '${insights.openSubmissionCount}',
        ),
        StatCard(
          icon: Icons.insights_outlined,
          label: strings.averageFitScoreLabel,
          value: '${insights.averageFitScorePercent}%',
        ),
      ],
    );
  }

  /// The real, per-BU "AI summary of expertise" (`generateBusinessUnitSummary`)
  /// — given top billing over `_buildAiInsight`'s opportunity-borrowed proxy,
  /// per the "AI insights more prominent than metadata" design rule.
  Widget _buildAiExpertiseSummary(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
  ) {
    final summary = businessUnit.aiExpertiseSummary;
    final highlights = businessUnit.aiExpertiseHighlights;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.secondary, width: 4),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      strings.aiExpertiseSummaryTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _generatingSummary
                        ? null
                        : () => _generateSummary(businessUnit.id),
                    icon: _generatingSummary
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _generatingSummary
                          ? strings.generatingAiSummaryLabel
                          : summary == null
                          ? strings.generateAiSummaryButton
                          : strings.refreshAiSummaryButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary == null)
                Text(strings.noAiExpertiseSummaryMessage)
              else ...[
                Text(summary, style: theme.textTheme.bodyMedium),
                if (highlights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final h in highlights) Chip(label: Text(h)),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsight(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
    BusinessUnitInsights insights,
  ) {
    final top = insights.topOpportunity;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    strings.sectionExecutiveSummary,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (top == null)
                Text(strings.businessUnitAiHeadlineNoReviewMessage)
              else ...[
                Text(
                  top.executiveRecommendation != null
                      ? strings.strategicReviewRecommendationLabel(
                          top.executiveRecommendation!,
                        )
                      : top.title,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FitScoreBadge(percent: top.fitScorePercent, size: 32),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        top.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunities(BuildContext context, List<Opportunity> items) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final o in items)
            ListTile(
              title: Text(
                o.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: PipelineStageBadge(stage: o.pipelineStage),
              trailing: FitScoreBadge(percent: o.fitScorePercent),
              onTap: () => pushSlideFade(
                context,
                OpportunityWorkspaceScreen(opportunityId: o.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProposals(
    BuildContext context,
    AppStrings strings,
    WidgetRef ref,
    List<Proposal> items,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final p in items)
            ListTile(
              title: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(strings.proposalStatusLabel(p.status)),
              onTap: () => pushSlideFade(
                context,
                ProposalWorkspaceScreen(opportunityId: p.opportunityId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmissions(
    BuildContext context,
    AppStrings strings,
    List<Submission> items,
    List<Opportunity> opportunities,
  ) {
    final opportunityById = {for (final o in opportunities) o.id: o};
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in items)
            ListTile(
              leading: Icon(
                Icons.send_outlined,
                color: submissionStatusColor(s.status),
              ),
              title: Text(
                opportunityById[s.opportunityId]?.title ??
                    strings.submissionWorkspaceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(strings.submissionStatusLabel(s.status)),
              onTap: () => pushSlideFade(
                context,
                SubmissionWorkspaceScreen(opportunityId: s.opportunityId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjects(BuildContext context, List<Project> items) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final p in items)
            ListTile(
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                p.client,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => pushSlideFade(
                context,
                ProjectWorkspaceScreen(projectId: p.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivity(
    BuildContext context,
    AppStrings strings,
    List<OpportunityEvent> events,
  ) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final event in events)
            ListTile(
              leading: const Icon(Icons.timeline_outlined),
              title: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(dateFormat.format(event.createdAt)),
              onTap: () => pushSlideFade(
                context,
                OpportunityWorkspaceScreen(opportunityId: event.opportunityId),
              ),
            ),
        ],
      ),
    );
  }

}