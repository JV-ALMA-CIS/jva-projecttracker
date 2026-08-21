import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunities_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/notification_tile.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// The Notification Center — a prioritized, grouped view over
/// [notificationsProvider] (itself derived from active AI Recommendations
/// and approaching opportunity deadlines; see ADR-007). Unlike a flat list,
/// items are split into two intelligently-grouped sections so a user can
/// scan "what does the AI recommend" separately from "what's time-
/// sensitive." "Mark all read" is the only standing action, and only shown
/// when there's something to mark — every other interaction is a tap on
/// the item itself (a contextual action, not a dedicated button per row).
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadIds = notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    final recommendationItems = [
      for (final n in notifications)
        if (n.type == NotificationType.recommendation) n,
    ];
    final deadlineItems = [
      for (final n in notifications)
        if (n.type == NotificationType.deadline) n,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.notificationCenterTitle),
        actions: [
          if (unreadIds.isNotEmpty)
            TextButton(
              onPressed: () => ref
                  .read(notificationReadIdsProvider.notifier)
                  .markAllRead(unreadIds),
              child: Text(strings.markAllReadButton),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  strings.noNotificationsYet,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (recommendationItems.isNotEmpty) ...[
                  SectionHeader(
                    title: strings.recommendationsGroupLabel,
                    accentColor: AppStatusColors.ai,
                  ),
                  for (final (i, n) in recommendationItems.indexed)
                    FadeSlideIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: NotificationTile(
                          notification: n,
                          onTap: () => pushSlideFade(
                            context,
                            const RecommendationsScreen(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (deadlineItems.isNotEmpty) ...[
                  SectionHeader(
                    title: strings.upcomingDeadlinesGroupLabel,
                    accentColor: AppStatusColors.warning,
                  ),
                  for (final (i, n) in deadlineItems.indexed)
                    FadeSlideIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: NotificationTile(
                          notification: n,
                          onTap: () => pushSlideFade(
                            context,
                            const OpportunitiesScreen(),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
