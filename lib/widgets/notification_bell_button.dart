import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/notifications/notification_center_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';

/// Notification Center entry point — same shape as `SettingsButton`, using
/// Material 3's own `Badge` widget for the unread count rather than a
/// custom-built one.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      onPressed: () => pushSlideFade(context, const NotificationCenterScreen()),
      tooltip: strings.notificationBellTooltip,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
