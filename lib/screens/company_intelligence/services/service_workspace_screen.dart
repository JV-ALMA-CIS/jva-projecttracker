import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/service_form_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capability_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industry_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_article_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/service_insights.dart';
import 'package:jva_projecttracker/services/service_summary_service.dart';
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

/// The Service Workspace — the third Company Intelligence entity to adopt
/// the workspace pattern. Two structural differences from
/// [ProductWorkspaceScreen]: [ServiceModel.businessUnitIds] is plural (a
/// service can belong to more than one business unit), and there is no
/// Experiences section — `Experience` has no `serviceIds` field to
/// reverse-query, so that section is simply omitted rather than
/// referencing a field that doesn't exist. See `providers.dart`'s
/// `service*Provider` family and `service_insights.dart`.
class ServiceWorkspaceScreen extends ConsumerWidget {
  const ServiceWorkspaceScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final serviceAsync = ref.watch(serviceByIdProvider(serviceId));

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
                title: strings.servicesTitle,
                action: IconButton(
                  onPressed: () => pushSlideFade(
                    context,
                    ServiceFormScreen(serviceId: serviceId),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: strings.editButton,
                ),
              ),
            ),
            Expanded(
              child: serviceAsync.when(
                data: (service) => service == null
                    ? const SizedBox.shrink()
                    : _Body(service: service),
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
  const _Body({required this.service});

  final ServiceModel service;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _generatingSummary = false;

  Future<void> _generateSummary(String serviceId) async {
    final strings = ref.read(appStringsProvider);
    setState(() => _generatingSummary = true);
    try {
      await ref
          .read(serviceSummaryServiceProvider)
          .generateSummary(serviceId: serviceId);
    } on ServiceSummaryException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.aiSummaryFailedMessage)));
      }
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  ServiceModel get service => widget.service;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final id = service.id;

    final businessUnits = ref.watch(serviceBusinessUnitsProvider(id));
    final opportunities = ref.watch(serviceOpportunitiesProvider(id));
    final proposals = ref.watch(serviceProposalsProvider(id));
    final submissions = ref.watch(serviceSubmissionsProvider(id));
    final projects = ref.watch(serviceAwardedProjectsProvider(id));
    final capabilities = ref.watch(serviceCapabilitiesProvider(id));
    final industries = ref.watch(serviceIndustriesProvider(id));
    final knowledgeArticles = ref.watch(serviceKnowledgeArticlesProvider(id));
    final recommendations = ref.watch(serviceRecommendationsProvider(id));
    final recentEvents = ref.watch(serviceRecentEventsProvider(id));
    final insights = ref.watch(serviceInsightsProvider(id));

    final hasAnyData =
        opportunities.isNotEmpty ||
        capabilities.isNotEmpty ||
        industries.isNotEmpty ||
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
        _buildHeader(context, theme, strings, businessUnits),
        const SizedBox(height: AppSpacing.xl),
        _buildKpis(context, theme, strings, insights),
        const SizedBox(height: AppSpacing.xl),
        _buildAiExpertiseSummary(context, theme, strings),
        const SizedBox(height: AppSpacing.xl),
        _buildAiInsight(context, theme, strings, insights),
        if (!hasAnyData) ...[
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            icon: Icons.miscellaneous_services_outlined,
            title: strings.noServiceDataMessage,
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
          _buildProposals(context, strings, proposals),
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
    List<BusinessUnit> businessUnits,
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
                  child: Text(service.name, style: theme.textTheme.titleLarge),
                ),
                Chip(
                  label: Text(service.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (businessUnits.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final u in businessUnits)
                    Chip(
                      label: Text(u.name),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (service.summary.isNotEmpty ||
                service.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                service.summary.isNotEmpty
                    ? service.summary
                    : service.description,
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
    ServiceInsights insights,
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

  Widget _buildAiExpertiseSummary(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
  ) {
    final summary = service.aiExpertiseSummary;
    final highlights = service.aiExpertiseHighlights;

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
                        : () => _generateSummary(service.id),
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
    ServiceInsights insights,
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
                Text(strings.serviceAiHeadlineNoReviewMessage)
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