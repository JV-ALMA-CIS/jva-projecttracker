import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';
import 'package:jva_projecttracker/services/notification_preferences_service.dart';
import 'package:jva_projecttracker/services/opportunities/opportunity_providers.dart';
import 'package:jva_projecttracker/services/recommendations/recommendation_providers.dart';

import 'settings_providers.dart';

final notificationPreferencesServiceProvider = Provider(
  (ref) => NotificationPreferencesService(ref.watch(sharedPreferencesProvider)),
);

/// Which Notification Center items this device has already read — see
/// `NotificationPreferencesService`. Mirrors [ThemeModeController]'s shape
/// exactly (load from the local-preferences service, write through on
/// every mutation).
class NotificationReadController extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref.watch(notificationPreferencesServiceProvider).readIds;

  void markRead(String id) {
    state = {...state, id};
    ref.read(notificationPreferencesServiceProvider).markRead(id);
  }

  void markAllRead(Iterable<String> ids) {
    state = {...state, ...ids};
    ref.read(notificationPreferencesServiceProvider).markAllRead(ids);
  }
}

final notificationReadIdsProvider =
    NotifierProvider<NotificationReadController, Set<String>>(
      NotificationReadController.new,
    );

/// The Notification Center's contents — derived (never persisted) from
/// live recommendations/opportunities via `buildNotifications`. See
/// ADR-007.
final notificationsProvider = Provider<List<NotificationItem>>((ref) {
  return buildNotifications(
    activeRecommendations: ref.watch(activeRecommendationsProvider),
    opportunities: ref.watch(opportunitiesStreamProvider).value ?? const [],
    readIds: ref.watch(notificationReadIdsProvider),
    now: DateTime.now(),
  );
});

/// The Notification Center bell badge's count.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

/// High-priority notifications only (recommendations or deadlines), for the
/// Dashboard's "Needs attention" section — same derive-then-filter idiom as
/// [activeRecommendationsProvider], just filtering [notificationsProvider]
/// (ADR-007) instead of adding a parallel data source.
final urgentAlertsProvider = Provider<List<NotificationItem>>((ref) {
  return ref
      .watch(notificationsProvider)
      .where((n) => n.priority == OpportunityPriority.high)
      .toList();
});
