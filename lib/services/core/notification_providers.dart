import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';
import 'package:jva_projecttracker/services/notification_preferences_service.dart';
import 'package:jva_projecttracker/services/opportunities/opportunity_providers.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';
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
///
/// Opportunities are pre-filtered through [isOffRegionOpportunity] before
/// reaching `buildNotifications`: the geography hard-filter
/// (`isAllowedCountry` in `functions/opportunityRelevance.js`) only gates
/// *new* writes going forward, so pre-existing off-region documents
/// (Toronto, Nigeria, North Carolina, etc., written before that filter
/// shipped) would otherwise still surface here — including in the
/// Dashboard's "Needs Your Attention" card, the very first thing a user
/// sees on login. This keeps that surface honest without needing every
/// stale document cleaned up first (see the bulk cleanup dialog's
/// "Off-region only" mode for that separate cleanup).
final notificationsProvider = Provider<List<NotificationItem>>((ref) {
  final opportunities =
      ref.watch(opportunitiesStreamProvider).value ?? const [];
  return buildNotifications(
    activeRecommendations: ref.watch(activeRecommendationsProvider),
    opportunities: opportunities
        .where((o) => !isOffRegionOpportunity(o))
        .toList(),
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
  // Also keeps `matchNotificationWatcherProvider` alive for as long as
  // anything watches this provider — see that provider's doc comment for
  // why it needs an always-mounted watcher.
  ref.watch(matchNotificationWatcherProvider);
  return ref
      .watch(notificationsProvider)
      .where((n) => n.priority == OpportunityPriority.high)
      .toList();
});

/// Durably records, on the opportunity document itself, the first time each
/// opportunity's match score crosses [kMatchScoreNotifyThreshold] within a
/// new ten-point bucket — the persisted counterpart to
/// [notificationsProvider]'s otherwise-ephemeral [NotificationType.matchScore]
/// items (see `buildNotifications`'s doc comment: that derivation has no
/// Firestore collection of its own, and the Notification Center's read-state
/// is device-local `SharedPreferences`, so neither survives a fresh install,
/// a different device, or the Notification Center simply never being
/// opened). Writes `lastNotifiedScore`/`matchNotificationSentAt` via
/// [OpportunityService.markMatchNotificationSent] exactly once per
/// newly-qualifying bucket per opportunity — an opportunity whose
/// `lastNotifiedScore` is already in the same bucket as its current score is
/// left untouched, so this never spams repeat writes for the same
/// (opportunity, bucket) pair. Still no FCM/push — this only makes the
/// existing in-app signal durable, per the "no FCM yet" scope.
///
/// Kept alive by [urgentAlertsProvider] (itself watched from `home_shell.dart`
/// for as long as the shell is mounted) rather than requiring its own
/// dedicated watch point in the widget tree.
final matchNotificationWatcherProvider =
    NotifierProvider<MatchNotificationWatcher, void>(
      MatchNotificationWatcher.new,
    );

/// How many `markMatchNotificationSent` writes [MatchNotificationWatcher]
/// will fire from a single `build()` pass. A safety net for a large backlog
/// of already-qualifying-but-unmarked opportunities (e.g. right after this
/// feature first shipped, or after a bulk import) — without a cap, a
/// collection with many qualifying opportunities would fire that many
/// writes in one frame, each one's own Firestore round-trip triggering a
/// fresh `opportunitiesStreamProvider` emission and therefore another
/// `build()` pass, saturating the app with rebuilds/writes on first load.
/// The remainder is simply picked up on a later emission (this provider is
/// re-triggered by the app's normal Firestore traffic constantly, not just
/// its own writes), so nothing is lost — it just spreads out instead of
/// bursting all at once.
const int kMaxMatchNotificationWritesPerPass = 20;

class MatchNotificationWatcher extends Notifier<void> {
  // Every "opportunityId:bucket" pair already written THIS SESSION.
  // shouldMarkMatchNotificationSent alone isn't enough to prevent a write
  // storm: it only becomes false once Opportunity.lastNotifiedScore has
  // round-tripped back through the live snapshot, which takes at least one
  // full Firestore write-then-read cycle. Until that round-trip completes,
  // every intervening `opportunitiesStreamProvider` emission (including the
  // one this very write itself causes) would otherwise still see the old,
  // unmarked opportunity and re-fire the same write — an unbounded loop of
  // writes begetting new snapshots begetting more writes. This local guard
  // closes that gap by remembering what's already been sent, independent of
  // whether Firestore has confirmed it back to us yet.
  final Set<String> _handledThisSession = {};

  @override
  void build() {
    final opportunities = ref.watch(opportunitiesStreamProvider).value;
    if (opportunities == null) return;

    var writesThisPass = 0;
    for (final opportunity in opportunities) {
      if (!shouldMarkMatchNotificationSent(opportunity)) continue;

      final score =
          opportunity.overallMatchScore ?? opportunity.fitScorePercent;
      final key = '${opportunity.id}:${matchScoreBucket(score)}';
      if (_handledThisSession.contains(key)) continue;
      if (writesThisPass >= kMaxMatchNotificationWritesPerPass) break;

      _handledThisSession.add(key);
      writesThisPass++;
      ref
          .read(opportunityServiceProvider)
          .markMatchNotificationSent(opportunity.id, score);
    }
  }
}
