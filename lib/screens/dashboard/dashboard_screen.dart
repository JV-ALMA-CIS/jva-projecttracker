import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/screens/notifications/notification_center_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/project_health.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/kpi_card.dart';
import 'package:jva_projecttracker/widgets/recommendation_card.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';
import 'package:jva_projecttracker/widgets/submission_status_style.dart';

/// Small colored dot placed before a [SectionHeader]'s title, giving each
/// section a consistent, scannable identity color without changing
/// `SectionHeader`'s own shared API.
Widget _sectionDot(Color color) => Container(
  width: 8,
  height: 8,
  margin: const EdgeInsets.only(right: AppSpacing.sm),
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);

/// Wraps a section row in a colored left accent rail + hover lift.
Widget _accentRow({required Color color, required Widget child}) {
  return HoverLift(
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: child,
    ),
  );
}

/// One unified, severity-ranked entry in "Needs Your Attention" — the
/// Dashboard's highest-priority section. Deliberately a Dashboard-local
/// union type rather than forcing opportunity deadlines, AI recommendation
/// alerts, and at-risk operational projects through one shared model: each
/// source already has its own real, correctly-typed provider
/// ([urgentAlertsProvider], [projectsNeedingAttentionProvider]) and this
/// just captures enough to render+sort them together without inventing new
/// alert types, per the "no fabricated data" constraint.
class _AttentionItem {
  const _AttentionItem({
    required this.severity,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color severity;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// The Dashboard as the executive operating center: every section answers
/// one of "what needs attention / what's the strongest opportunity / what's
/// the AI's reasoning / what's being delivered / how healthy is our
/// knowledge" — never a raw feature list. Section order follows a fixed
/// priority (attention > opportunity intelligence > submissions >
/// operational projects > company intelligence > activity), matching how
/// urgently each answers "what should I look at right now."
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openOpportunityAlert(
    BuildContext context,
    WidgetRef ref,
    NotificationItem n,
  ) {
    ref.read(notificationReadIdsProvider.notifier).markRead(n.id);
    if (n.type == NotificationType.recommendation) {
      pushSlideFade(context, const RecommendationsScreen());
      return;
    }
    if (n.relatedOpportunityIds.isEmpty) {
      ref.read(selectedTabIndexProvider.notifier).index = 2;
      return;
    }
    pushSlideFade(
      context,
      OpportunityWorkspaceScreen(opportunityId: n.relatedOpportunityIds.first),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    final knowledgeOverview = ref.watch(knowledgeGraphOverviewProvider);
    final topOpportunities = ref.watch(topOpportunitiesProvider);
    final topRecommendations = ref.watch(topRecommendationsProvider);
    final urgentAlerts = ref.watch(urgentAlertsProvider);
    final topSubmissions = ref.watch(topSubmissionsProvider);
    final submissions = ref.watch(submissionsStreamProvider).value ?? const [];
    final opportunities =
        ref.watch(opportunitiesStreamProvider).value ?? const [];
    final recentActivity = ref.watch(recentOpportunityEventsProvider);
    final projectsNeedingAttention = ref.watch(
      projectsNeedingAttentionProvider,
    );
    final portfolio = ref.watch(projectPortfolioMetricsProvider);
    final inboxOpportunities = ref.watch(inboxOpportunitiesProvider);
    final submissionsWithBlockers = ref.watch(submissionsWithBlockersProvider);
    final activeProjects = (ref.watch(projectsStreamProvider).value ?? const [])
        .where((p) => p.status == ProjectStatus.running)
        .toList();
    final operationalProjects = ref.watch(operationalProjectsProvider);
    final awardedWithoutProject = ref.watch(awardedWithoutProjectProvider);
    final openSubmissionCount = submissions
        .where((s) => !s.status.isClosed)
        .length;
    final activeOpportunityCount = opportunities
        .where(
          (o) =>
              o.pipelineStage != OpportunityPipelineStage.lost &&
              o.pipelineStage != OpportunityPipelineStage.completed,
        )
        .length;
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    // --- Needs Your Attention: merges opportunity/recommendation alerts
    // with at-risk operational projects into one severity-sorted list. ---
    final attentionItems = <_AttentionItem>[
      for (final alert in urgentAlerts)
        _AttentionItem(
          severity: AppStatusColors.danger,
          icon: alert.type == NotificationType.recommendation
              ? Icons.lightbulb_outline
              : Icons.event_busy_outlined,
          title: alert.title,
          subtitle: alert.body ?? '',
          onTap: () => _openOpportunityAlert(context, ref, alert),
        ),
      for (final project in projectsNeedingAttention)
        _AttentionItem(
          severity: AppStatusColors.warning,
          icon: Icons.construction_outlined,
          title: project.name,
          subtitle: ref
              .watch(projectHealthProvider(project.id))
              .reasons
              .join(' · '),
          onTap: () => pushSlideFade(
            context,
            ProjectWorkspaceScreen(projectId: project.id),
          ),
        ),
      for (final entry in submissionsWithBlockers)
        _AttentionItem(
          severity: AppStatusColors.warning,
          icon: Icons.send_outlined,
          title: entry.opportunity?.title ?? strings.submissionWorkspaceTitle,
          subtitle: strings.submissionNeedsActionSubtitle,
          onTap: () => pushSlideFade(
            context,
            SubmissionWorkspaceScreen(
              opportunityId: entry.submission.opportunityId,
            ),
          ),
        ),
      for (final opportunity in inboxOpportunities)
        _AttentionItem(
          severity: AppStatusColors.info,
          icon: Icons.inbox_outlined,
          title: opportunity.title,
          subtitle: strings.opportunityAwaitingTriageSubtitle,
          onTap: () => pushSlideFade(
            context,
            OpportunityWorkspaceScreen(opportunityId: opportunity.id),
          ),
        ),
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Executive greeting ---
          FadeSlideIn(
            index: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.10),
                    theme.colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.dashboardGreeting(
                      userProfile?.email.split('@').first ?? '',
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.dashboardSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // --- KPI row ---
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final cards = [
                KpiCard(
                  label: strings.activeOpportunitiesLabel,
                  value: '$activeOpportunityCount',
                  icon: Icons.travel_explore_outlined,
                  accentColor: theme.colorScheme.primary,
                  onTap: () =>
                      ref.read(selectedTabIndexProvider.notifier).index = 2,
                ),
                KpiCard(
                  label: strings.openSubmissionsLabel,
                  value: '$openSubmissionCount',
                  icon: Icons.send_outlined,
                  accentColor: AppStatusColors.info,
                  onTap: () =>
                      ref.read(selectedTabIndexProvider.notifier).index = 4,
                ),
                KpiCard(
                  label: strings.activeProjectsSectionTitle,
                  value: '${activeProjects.length}',
                  icon: Icons.construction_outlined,
                  accentColor: AppStatusColors.success,
                  onTap: activeProjects.isEmpty
                      ? null
                      : () => pushSlideFade(
                          context,
                          ProjectWorkspaceScreen(
                            projectId: activeProjects.first.id,
                          ),
                        ),
                ),
                KpiCard(
                  label: strings.atRiskLabel,
                  value: '${portfolio.attentionRequiredCount}',
                  icon: Icons.warning_amber_outlined,
                  accentColor: portfolio.attentionRequiredCount > 0
                      ? AppStatusColors.warning
                      : AppStatusColors.success,
                ),
              ];
              return GridView.count(
                crossAxisCount: compact ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: compact ? 1.5 : 1.3,
                children: cards,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Needs Your Attention ---
          Row(
            children: [
              _sectionDot(AppStatusColors.danger),
              Expanded(
                child: SectionHeader(
                  title: strings.needsYourAttentionSectionTitle,
                  trailing: TextButton(
                    onPressed: () => pushSlideFade(
                      context,
                      const NotificationCenterScreen(),
                    ),
                    child: Text(strings.viewAllRecommendationsButton),
                  ),
                ),
              ),
            ],
          ),
          if (attentionItems.isEmpty)
            EmptyState(
              icon: Icons.check_circle_outline,
              title: strings.youreAllCaughtUpMessage,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, item) in attentionItems.indexed)
                  FadeSlideIn(
                    index: i,
                    child: _accentRow(
                      color: item.severity,
                      child: Card(
                        child: ListTile(
                          leading: Icon(item.icon, color: item.severity),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: item.subtitle.isEmpty
                              ? null
                              : Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: item.onTap,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          // --- Opportunity Intelligence ---
          Row(
            children: [
              _sectionDot(theme.colorScheme.primary),
              Expanded(
                child: SectionHeader(
                  title: strings.topOpportunityMatches,
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(selectedTabIndexProvider.notifier).index = 2,
                    child: Text(strings.viewAllRecommendationsButton),
                  ),
                ),
              ),
            ],
          ),
          if (topOpportunities.isEmpty)
            EmptyState(
              icon: Icons.travel_explore_outlined,
              title: strings.noOpportunitiesOnDashboard,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, o) in topOpportunities.indexed)
                  FadeSlideIn(
                    index: i,
                    child: _accentRow(
                      color: theme.colorScheme.primary,
                      child: Card(
                        child: ListTile(
                          title: Text(
                            o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            o.client ?? o.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: FitScoreBadge(percent: o.fitScorePercent),
                          onTap: () => pushSlideFade(
                            context,
                            OpportunityWorkspaceScreen(opportunityId: o.id),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                strings.aiRecommendationsSectionTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (topRecommendations.isEmpty)
            EmptyState(
              icon: Icons.lightbulb_outline,
              title: strings.noAiRecommendationsGroundedMessage,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, recommendation) in topRecommendations.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: FadeSlideIn(
                      index: i,
                      child: RecommendationCard(
                        recommendation: recommendation,
                        compact: true,
                        onTap: () => pushSlideFade(
                          context,
                          const RecommendationsScreen(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          // --- Submissions ---
          Row(
            children: [
              _sectionDot(AppStatusColors.info),
              Expanded(
                child: SectionHeader(title: strings.submissionsSectionTitle),
              ),
            ],
          ),
          if (submissions.isNotEmpty) ...[
            Text(
              strings.submissionStatusOverviewLabel,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final status in SubmissionStatus.values)
                  if (submissions.where((s) => s.status == status).isNotEmpty)
                    StatusBadge(
                      label:
                          '${strings.submissionStatusLabel(status)} · '
                          '${submissions.where((s) => s.status == status).length}',
                      color: submissionStatusColor(status),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (topSubmissions.isEmpty)
            EmptyState(
              icon: Icons.send_outlined,
              title: strings.noOpenSubmissions,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, entry) in topSubmissions.indexed)
                  FadeSlideIn(
                    index: i,
                    child: _accentRow(
                      color: submissionStatusColor(entry.submission.status),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: submissionStatusColor(
                              entry.submission.status,
                            ).withValues(alpha: 0.15),
                            child: Icon(
                              Icons.send_outlined,
                              color: submissionStatusColor(
                                entry.submission.status,
                              ),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            entry.opportunity?.title ??
                                strings.submissionWorkspaceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            strings.submissionStatusLabel(
                              entry.submission.status,
                            ),
                          ),
                          onTap: () => pushSlideFade(
                            context,
                            SubmissionWorkspaceScreen(
                              opportunityId: entry.submission.opportunityId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          // --- Operational Projects ---
          Row(
            children: [
              _sectionDot(AppStatusColors.success),
              Expanded(
                child: SectionHeader(title: strings.activeProjectsSectionTitle),
              ),
            ],
          ),
          if (activeProjects.isEmpty)
            EmptyState(
              icon: Icons.construction_outlined,
              title: strings.noActiveProjectsMessage,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, project) in activeProjects.indexed)
                  Builder(
                    builder: (context) {
                      final health = ref.watch(
                        projectHealthProvider(project.id),
                      );
                      final healthColor = switch (health.overall) {
                        ProjectHealthLevel.healthy => AppStatusColors.success,
                        ProjectHealthLevel.atRisk => AppStatusColors.warning,
                        ProjectHealthLevel.critical => AppStatusColors.danger,
                      };
                      return FadeSlideIn(
                        index: i,
                        child: _accentRow(
                          color: healthColor,
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.circle,
                                size: 12,
                                color: healthColor,
                              ),
                              title: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                project.client,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => pushSlideFade(
                                context,
                                ProjectWorkspaceScreen(projectId: project.id),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          // --- Delivery & Wins ---
          // Distinct from "Active Projects" above (which only watches
          // ProjectStatus.running): this answers "which tenders have we
          // won, and is delivery started" — awarded/projectStarted
          // opportunities with no linked Project yet (action needed, per
          // A1) alongside every planned/running operational project (A2),
          // reusing `awardedWithoutProjectProvider`/
          // `operationalProjectsProvider` so this and the Opportunities/
          // Projects screens never disagree about what counts.
          Row(
            children: [
              _sectionDot(AppStatusColors.ai),
              Expanded(
                child: SectionHeader(
                  title: strings.deliveryAndWinsSectionTitle,
                ),
              ),
            ],
          ),
          if (awardedWithoutProject.isEmpty && operationalProjects.isEmpty)
            EmptyState(
              icon: Icons.emoji_events_outlined,
              title: strings.noDeliveryAndWinsMessage,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (i, opportunity)
                    in awardedWithoutProject.take(5).indexed)
                  FadeSlideIn(
                    index: i,
                    child: _accentRow(
                      color: AppStatusColors.warning,
                      child: Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.play_circle_outline,
                            color: AppStatusColors.warning,
                          ),
                          title: Text(
                            opportunity.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(strings.startProjectNeededLabel),
                          onTap: () => pushSlideFade(
                            context,
                            OpportunityWorkspaceScreen(
                              opportunityId: opportunity.id,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final (i, project) in operationalProjects.take(5).indexed)
                  FadeSlideIn(
                    index: awardedWithoutProject.length + i,
                    child: _accentRow(
                      color: AppStatusColors.success,
                      child: Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.construction_outlined,
                            color: AppStatusColors.success,
                          ),
                          title: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            strings.projectStatusLabel(project.status),
                          ),
                          onTap: () => pushSlideFade(
                            context,
                            ProjectWorkspaceScreen(projectId: project.id),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          // --- Company Intelligence health ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sectionDot(Colors.deepPurple),
                    Flexible(
                      child: SectionHeader(
                        title: strings.companyIntelligenceTitle,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(selectedTabIndexProvider.notifier).index = 3,
                child: Text(strings.viewCompanyIntelligenceButton),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _KnowledgeStat(
                icon: Icons.hub_outlined,
                label: strings.totalKnowledgeItemsLabel,
                value: '${knowledgeOverview.totalEntities}',
                onTap: () =>
                    ref.read(selectedTabIndexProvider.notifier).index = 3,
              ),
              _KnowledgeStat(
                icon: Icons.warning_amber_outlined,
                label: strings.capabilityGapsLabel,
                value: '${knowledgeOverview.capabilityGapCount}',
                accentColor: knowledgeOverview.capabilityGapCount > 0
                    ? AppStatusColors.warning
                    : null,
                onTap: () =>
                    ref.read(selectedTabIndexProvider.notifier).index = 3,
              ),
              _KnowledgeStat(
                icon: Icons.update_outlined,
                label: strings.updatedRecentlyLabel,
                value: '${knowledgeOverview.recentlyUpdatedCount}',
                onTap: () =>
                    ref.read(selectedTabIndexProvider.notifier).index = 3,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Recent activity ---
          Row(
            children: [
              _sectionDot(Colors.blueGrey),
              Expanded(
                child: SectionHeader(title: strings.recentActivitySectionTitle),
              ),
            ],
          ),
          recentActivity.when(
            data: (events) => events.isEmpty
                ? EmptyState(
                    icon: Icons.history_outlined,
                    title: strings.noRecentActivity,
                    compact: true,
                  )
                : Column(
                    children: [
                      for (final (i, event) in events.indexed)
                        FadeSlideIn(
                          index: i,
                          child: _accentRow(
                            color: Colors.blueGrey,
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.timeline_outlined),
                                title: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  dateFormat.format(event.createdAt),
                                ),
                                onTap: () => pushSlideFade(
                                  context,
                                  OpportunityWorkspaceScreen(
                                    opportunityId: event.opportunityId,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(strings.errorPrefix(e)),
          ),
        ],
      ),
    );
  }
}

/// A compact Company Intelligence stat — replaces the old fixed-width
/// [StatCard] row with a [Wrap] so the section survives narrow widths
/// without horizontal overflow.
class _KnowledgeStat extends StatelessWidget {
  const _KnowledgeStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    return SizedBox(
      width: 200,
      child: HoverLift(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.input),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: theme.textTheme.titleMedium),
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
