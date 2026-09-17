import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
///   listens for [FirebaseMessaging.onMessage] and surfaces a tappable
///   [SnackBar] instead.
///
/// A plain class rather than a Riverpod provider: nothing here depends on
/// app state beyond the (already-global) [navigatorKey], and it must be
/// set up once, unconditionally, at startup — before sign-in, unlike
/// `FcmTokenService` (which does depend on a signed-in uid).
class PushNotificationService {
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    FirebaseMessaging.onMessage.listen(
      (message) => _showForegroundBanner(message, navigatorKey),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigate(message, navigatorKey),
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(initialMessage, navigatorKey);
    }
  }

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
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          notification.body == null
              ? notification.title ?? ''
              : '${notification.title ?? ''}\n${notification.body}',
        ),
        action: opportunityId == null
            ? null
            : SnackBarAction(
                label: 'View',
                onPressed: () => _navigate(message, navigatorKey),
              ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _navigate(
    RemoteMessage message,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final opportunityId = opportunityIdFromMessageData(message.data);
    if (opportunityId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) =>
            OpportunityWorkspaceScreen(opportunityId: opportunityId),
      ),
    );
  }
}
