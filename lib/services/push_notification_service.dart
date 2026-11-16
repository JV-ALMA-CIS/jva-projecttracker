import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jva_projecttracker/firebase_options.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';

/// The `opportunityId` a push's data payload should carry for
/// [PushNotificationService] to deep-link a tap straight to that
/// opportunity. Shared with `functions/matchScorePushNotification.js`,
/// which sets this same key when it builds the FCM message — keep both in
/// sync if either changes.
const kNotificationDataOpportunityIdKey = 'opportunityId';

/// Reads the opportunity to deep-link to out of a push's `data` payload, or
/// null if this message doesn't carry one (e.g. a future notification type
/// with nothing to deep-link to). Pulled out as a pure function so the
/// parsing is unit-testable without a real [RemoteMessage].
String? opportunityIdFromMessageData(Map<String, dynamic> data) {
  final id = data[kNotificationDataOpportunityIdKey];
  return id is String && id.isNotEmpty ? id : null;
}

/// Handles a push that arrives while the app is fully backgrounded or
/// terminated, on Android/iOS (web instead uses `firebase-messaging-sw.js`'s
/// own `onBackgroundMessage`, since a Dart isolate isn't running at all in
/// that case). Android/iOS already display the message's `notification`
/// payload as a system tray entry automatically without this handler — its
/// only job is making sure the plugin has a registered background handler at
/// all (FlutterFire logs a warning and may drop data-only messages
/// otherwise) and giving a place to add background data handling later.
///
/// Must be a top-level (or static) function: it runs in its own headless
/// isolate, separate from the running app, so it cannot close over any
/// app state and must re-initialize Firebase itself.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Wires up push notification display/navigation for every app state:
///
/// - **Terminated**: the OS shows the system notification on its own
///   (Android/iOS) or the service worker does (web — see
///   `firebase-messaging-sw.js`). [initialize] additionally checks
///   [FirebaseMessaging.getInitialMessage] once at startup, to deep-link
///   straight to the relevant opportunity if that's what launched the app.
/// - **Backgrounded**: same automatic system display; a tap is delivered to
///   the now-foregrounded app via [FirebaseMessaging.onMessageOpenedApp],
///   which [initialize] listens for to deep-link.
/// - **Foreground (open)**: the OS does *not* display anything on its own
///   (this is standard FCM/APNs/web-push behavior, not a bug) — the app's
///   own Notification Center already reflects new data live via Firestore
///   streams regardless, but a push arriving while the user is looking at a
///   different screen would otherwise be silently missed, so [initialize]
///   listens for [FirebaseMessaging.onMessage] and surfaces a
///   [MaterialBanner] with an "Open" button instead (iOS additionally shows
///   its own system banner).
///
/// A plain class rather than a Riverpod provider: nothing here depends on
/// app state beyond the (already-global) [navigatorKey], and it must be
/// set up once, unconditionally, at startup — before sign-in, unlike
/// `FcmTokenService` (which does depend on a signed-in uid).
class PushNotificationService {
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    // iOS hides notifications while the app is open unless told otherwise —
    // show the system banner + sound in the foreground too, same as when
    // backgrounded. No-op on Android/web.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(
      (message) => _showForegroundBanner(message, navigatorKey),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigate(message.data, navigatorKey),
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(initialMessage.data, navigatorKey);
      return;
    }

    // Web: a clicked browser notification opens the app at
    // `/?opportunityId=...` (the push's webpush.fcmOptions.link — see
    // functions/matchScorePushNotification.js), since the service worker
    // can't use in-app routing itself.
    if (kIsWeb) {
      final webOpportunityId = opportunityIdFromMessageData(
        Uri.base.queryParameters,
      );
      if (webOpportunityId != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _navigate(<String, dynamic>{
            kNotificationDataOpportunityIdKey: webOpportunityId,
          }, navigatorKey),
        );
      }
    }
  }

  /// Android and web don't show a system notification while the app is
  /// open, so a push arriving then is surfaced as a prominent in-app banner
  /// at the top of the screen, with a button straight to the tender. (iOS
  /// also shows its own system banner — see
  /// setForegroundNotificationPresentationOptions above.)
  void _showForegroundBanner(
    RemoteMessage message,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final notification = message.notification;
    if (notification == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final opportunityId = opportunityIdFromMessageData(message.data);
    final colors = Theme.of(context).colorScheme;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: colors.primaryContainer,
        leading: Icon(
          Icons.notifications_active,
          color: colors.onPrimaryContainer,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            if (notification.body != null)
              Text(
                notification.body!,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
          if (opportunityId != null)
            FilledButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _navigate(message.data, navigatorKey);
              },
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }

  void _navigate(
    Map<String, dynamic> data,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final opportunityId = opportunityIdFromMessageData(data);
    if (opportunityId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) =>
            OpportunityWorkspaceScreen(opportunityId: opportunityId),
      ),
    );
  }
}
