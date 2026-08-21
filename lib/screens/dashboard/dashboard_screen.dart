import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
//import 'package:jva_projecttracker/models/opportunity.dart';
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
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Wraps a section item in a colored left accent rail + hover lift.
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

/// One compact "count + short label" stat inside the greeting header — the
/// header previously spent its entire height on decorative gradient text
/// with zero data in it. Reuses each section's own title as the label
/// (`needsYourAttentionSectionTitle`, etc.) rather than introducing new
/// strings, and reuses each section's own severity color, so a number here
/// visually points straight at the section below it that explains it.
Widget _headerStat({
  required IconData icon,
  required int count,
  required String label,
  required Color color,
  required ThemeData theme,
  Color? labelColor,
}) {
  return Expanded(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: labelColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A short vertical divider between [_headerStat] items. [color] should be
/// the same onContainer tone used for the surrounding text (the default
/// `outlineVariant` this replaced was tuned for a plain surface background
/// and read as nearly invisible against a colored container).
Widget _headerStatDivider(ThemeData theme, {Color? color}) {
  return Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    color:
        color?.withValues(alpha: 0.3) ??
        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
  );
}

/// A small colored icon chip for a list row's leading icon — reuses
/// `AppStatusColors.container()`, the same low-alpha tint formula every
/// status badge/chip in the app already uses, rather than introducing a new
/// one. Deliberately restrained (soft container tint, not a saturated fill)
/// per the standard "neutral base + a couple of meaningful accents" guidance
/// for dashboard color — the row's left accent rail already carries the
/// severity signal; this just keeps the same color legible at the icon
/// instead of leaving it a flat, undifferentiated grey/black icon the way
/// every row here did before.
Widget _iconChip(IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppStatusColors.container(color),
      borderRadius: BorderRadius.circular(AppRadii.input),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

/// One unified, severity-ranked entry in "Needs Your Attention".
///
/// This is intentionally Dashboard-local. The Dashboard combines existing
/// provider outputs without introducing a new business/domain model.
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

/// The Dashboard is the executive operating center.
///
/// Its job is not to reproduce every module in the application. It answers
/// four questions:
///
/// 1. What needs my attention?
/// 2. Which opportunities deserve attention?
/// 3. What have we won?
/// 4. What are we currently delivering?
///
/// Detailed management remains in the dedicated modules.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openOpportunityAlert(
    BuildContext context,
    WidgetRef ref,
    NotificationItem notification,
  ) {
    ref.read(notificationReadIdsProvider.notifier).markRead(notification.id);

    if (notification.type == NotificationType.recommendation) {
      pushSlideFade(context, const RecommendationsScreen());
      return;
    }

    if (notification.relatedOpportunityIds.isEmpty) {
      ref.read(selectedTabIndexProvider.notifier).index = 2;
      return;
    }

    pushSlideFade(
      context,
      OpportunityWorkspaceScreen(
        opportunityId: notification.relatedOpportunityIds.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    // -----------------------------------------------------------------------
    // EXISTING REAL PROVIDERS
    // -----------------------------------------------------------------------

    final topOpportunities = ref.watch(topOpportunitiesProvider);
    final urgentAlerts = ref.watch(urgentAlertsProvider);

    final projectsNeedingAttention = ref.watch(
      projectsNeedingAttentionProvider,
    );

    final inboxOpportunities = ref.watch(inboxOpportunitiesProvider);

    final submissionsWithBlockers = ref.watch(submissionsWithBlockersProvider);

    final awardedWithoutProject = ref.watch(awardedWithoutProjectProvider);

    final operationalProjects = ref.watch(operationalProjectsProvider);

    // -----------------------------------------------------------------------
    // NEEDS YOUR ATTENTION
    // -----------------------------------------------------------------------
    //
    // This is the most important Dashboard section.
    //
    // It combines existing actionable information:
    // - urgent opportunity/recommendation alerts
    // - projects needing attention
    // - blocked submissions
    // - opportunities awaiting triage
    //
    // No new business rules are introduced here.
    // -----------------------------------------------------------------------

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

    const attentionDisplayLimit = 5;

    final visibleAttentionItems = attentionItems
        .take(attentionDisplayLimit)
        .toList();

    // -----------------------------------------------------------------------
    // BUILD
    // -----------------------------------------------------------------------

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =================================================================
          // 1. EXECUTIVE GREETING
          // =================================================================
          FadeSlideIn(
            index: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                // Was `primary.withValues(alpha: 0.10/0.02)` — at that
                // alpha, a dark navy `primary` reads as a flat near-black
                // smear rather than a color, and the exact result varies
                // with theme mode since it depends on what's blending
                // underneath. `primaryContainer`/`secondaryContainer` are
                // solid Material 3 tokens tuned to always read as visibly
                // colored *and* legible with their matching `onContainer`
                // text color, in both light and dark mode — no guessing at
                // alpha needed.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    Color.lerp(
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                      0.6,
                    )!,
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
                      // Was left to the default (onSurface) color, which
                      // assumed a near-white background — now that the
                      // container itself carries real color, text needs
                      // the matching onContainer color to stay legible.
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.dashboardSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Was `onSurfaceVariant`, also tuned for a plain
                      // surface — dimmed onPrimaryContainer instead.
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _headerStat(
                        icon: Icons.priority_high_rounded,
                        count: attentionItems.length,
                        label: strings.needsYourAttentionSectionTitle,
                        color: AppStatusColors.danger,
                        labelColor: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.75),
                        theme: theme,
                      ),
                      _headerStatDivider(theme, color: theme.colorScheme.onPrimaryContainer),
                      _headerStat(
                        icon: Icons.travel_explore_outlined,
                        count: topOpportunities.length,
                        label: strings.topOpportunityMatches,
                        color: AppStatusColors.info,
                        labelColor: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.75),
                        theme: theme,
                      ),
                      _headerStatDivider(theme, color: theme.colorScheme.onPrimaryContainer),
                      _headerStat(
                        icon: Icons.emoji_events_outlined,
                        count:
                            awardedWithoutProject.length +
                            operationalProjects.length,
                        label: strings.deliveryAndWinsSectionTitle,
                        color: AppStatusColors.success,
                        labelColor: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.75),
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // =================================================================
          // 2. NEEDS YOUR ATTENTION
          // =================================================================
          SectionHeader(
            title: strings.needsYourAttentionSectionTitle,
            accentColor: AppStatusColors.danger,
            trailing: attentionItems.length > attentionDisplayLimit
                ? TextButton(
                    onPressed: () => pushSlideFade(
                      context,
                      const NotificationCenterScreen(),
                    ),
                    child: Text(strings.viewAllButton),
                  )
                : null,
          ),

          if (visibleAttentionItems.isEmpty)
            EmptyState(
              icon: Icons.check_circle_outline,
              title: strings.youreAllCaughtUpMessage,
              compact: true,
            )
          else
            Column(
              children: [
                for (final (index, item) in visibleAttentionItems.indexed)
                  FadeSlideIn(
                    index: index,
                    child: _accentRow(
                      color: item.severity,
                      child: Card(
                        color: AppStatusColors.container(item.severity),
                        child: ListTile(
                          leading: _iconChip(item.icon, item.severity),
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

          // =================================================================
          // 3. PRIORITY OPPORTUNITIES
          // =================================================================
          //
          // This replaces the old:
          // - Opportunity Intelligence section
          // - separate AI Recommendations section
          //
          // AI remains available inside the opportunity workflow and through
          // the Recommendations module. The Dashboard simply surfaces the
          // strongest opportunities instead of duplicating the full AI feed.
          // =================================================================
          SectionHeader(
            title: strings.topOpportunityMatches,
            accentColor: AppStatusColors.info,
            trailing: TextButton(
              onPressed: () =>
                  ref.read(selectedTabIndexProvider.notifier).index = 2,
              child: Text(strings.viewAllButton),
            ),
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
                for (final (index, opportunity)
                    in topOpportunities.take(5).indexed)
                  FadeSlideIn(
                    index: index,
                    child: _accentRow(
                      color: theme.colorScheme.primary,
                      child: Card(
                        color: AppStatusColors.container(
                          theme.colorScheme.primary,
                        ),
                        child: ListTile(
                          leading: _iconChip(
                            Icons.travel_explore_outlined,
                            theme.colorScheme.primary,
                          ),
                          title: Text(
                            opportunity.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            opportunity.client ?? opportunity.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: FitScoreBadge(
                            percent: opportunity.fitScorePercent,
                          ),
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
              ],
            ),

          const SizedBox(height: AppSpacing.xl),

          // =================================================================
          // 4. WINS & DELIVERY
          // =================================================================
          //
          // This deliberately combines:
          //
          // - awarded opportunities that still need Start Project
          // - operational projects already underway
          //
          // This answers:
          //
          // "What have we won, and what are we delivering?"
          //
          // It replaces the old separate:
          // - Active Projects section
          // - Delivery & Wins section
          // =================================================================
          SectionHeader(
            title: strings.deliveryAndWinsSectionTitle,
            accentColor: AppStatusColors.success,
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
                // -----------------------------------------------------------
                // Awarded but project not started
                // -----------------------------------------------------------
                for (final (index, opportunity)
                    in awardedWithoutProject.take(5).indexed)
                  FadeSlideIn(
                    index: index,
                    child: _accentRow(
                      color: AppStatusColors.warning,
                      child: Card(
                        color: AppStatusColors.container(
                          AppStatusColors.warning,
                        ),
                        child: ListTile(
                          leading: _iconChip(
                            Icons.emoji_events_outlined,
                            AppStatusColors.warning,
                          ),
                          title: Text(
                            opportunity.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(strings.startProjectNeededLabel),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                          ),
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

                // -----------------------------------------------------------
                // Operational projects
                // -----------------------------------------------------------
                for (final (index, project)
                    in operationalProjects.take(5).indexed)
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
                        index: awardedWithoutProject.length + index,
                        child: _accentRow(
                          color: healthColor,
                          child: Card(
                            color: AppStatusColors.container(healthColor),
                            child: ListTile(
                              leading: _iconChip(
                                Icons.construction_outlined,
                                healthColor,
                              ),
                              title: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                project.client.isEmpty
                                    ? strings.projectStatusLabel(project.status)
                                    : '${strings.projectStatusLabel(project.status)} · '
                                          '${project.client}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                switch (health.overall) {
                                  ProjectHealthLevel.healthy =>
                                    Icons.check_circle_outline,
                                  ProjectHealthLevel.atRisk =>
                                    Icons.warning_amber_outlined,
                                  ProjectHealthLevel.critical =>
                                    Icons.error_outline,
                                },
                                color: healthColor,
                                size: 20,
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

          // =================================================================
          // END
          // =================================================================
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}