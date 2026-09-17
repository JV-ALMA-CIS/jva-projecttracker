import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/priority_style.dart';

/// One row in the Notification Center — reused identically for both
/// [NotificationType.recommendation] and [NotificationType.deadline] items,
/// the way `RecommendationCard` is reused across the Dashboard and
/// `RecommendationsScreen`. Tapping marks the item read (locally, via
/// `notificationReadIdsProvider`) and invokes [onTap] for navigation.
class NotificationTile extends ConsumerWidget {
  const NotificationTile({super.key, required this.notification, this.onTap});

  final NotificationItem notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final (background, foreground) = priorityColors(
      theme.colorScheme,
      notification.priority,
    );

    final subtitle = switch (notification.type) {
      NotificationType.recommendation => notification.body ?? '',
      NotificationType.deadline => _deadlineText(
        strings,
        notification.daysUntilDeadline ?? 0,
      ),
      NotificationType.matchScore => strings.matchScoreNotificationSubtitle(
        notification.matchScorePercent ?? 0,
      ),
    };

    return Card(
      child: ListTile(
        onTap: () {
          ref
              .read(notificationReadIdsProvider.notifier)
              .markRead(notification.id);
          onTap?.call();
        },
        leading: CircleAvatar(
          backgroundColor: background,
          child: Icon(
            switch (notification.type) {
              NotificationType.recommendation => Icons.auto_awesome_outlined,
              NotificationType.deadline => Icons.schedule_outlined,
              NotificationType.matchScore => Icons.trending_up_outlined,
            },
            color: foreground,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: notification.isRead
              ? theme.textTheme.titleSmall
              : theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  String _deadlineText(AppStrings strings, int daysLeft) {
    if (daysLeft < 0) return strings.deadlineOverdueLabel(-daysLeft);
    if (daysLeft == 0) return strings.deadlineDueTodayLabel;
    return strings.deadlineDueInLabel(daysLeft);
  }
}
