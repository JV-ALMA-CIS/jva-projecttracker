import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/firebase_options.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/services/core/navigation_providers.dart';
import 'package:jva_projecttracker/services/web_system_notifier_stub.dart'
    if (dart.library.js_interop) 'package:jva_projecttracker/services/web_system_notifier_web.dart';

/// The `opportunityId` a push's data payload should carry for
/// [PushNotificationService] to deep-link a tap straight to that
/// opportunity. Shared with `functions/matchScorePushNotification.js`,
/// which sets this same key when it builds the FCM message — keep both in
/// sync if either changes.
const kNotificationDataOpportunityIdKey = 'opportunityId';

/// Android channel ids → names. Must match MainActivity.kt (which creates
/// them) and `channelForType` in functions/matchScorePushNotification.js.
const Map<String, String> kAndroidChannels = <String, String>{
  'opportunities': 'New tenders & grants',
  'deadlines': 'Deadline reminders',
  'team': 'Shared by colleagues',
  'summary': 'Weekly summary',
  'general': 'Other alerts',
};

/// Reads the opportunity to deep-link to out of a push's `data` payload, or
/// null if this message doesn't carry one. Pure, so it's unit-testable
/// without a real [RemoteMessage].
String? opportunityIdFromMessageData(Map<String, dynamic> data) {
  final id = data[kNotificationDataOpportunityIdKey];
  return id is String && id.isNotEmpty ? id : null;
}

/// Turns a notification click-through link (`.../?opportunityId=X` or
/// `.../?open=inbox`) back into the same navigation data a push carries.
Map<String, dynamic> navigationDataFromLink(String link) {
  final Map<String, String> query =
      Uri.tryParse(link)?.queryParameters ?? const {};
  if (query['open'] == 'inbox') return const {'open': 'inbox'};
  final String? id = opportunityIdFromMessageData(query);
  if (id == null) return const {};
  return {kNotificationDataOpportunityIdKey: id};
}

/// What to show as a system notification for a push that arrived while the
/// app is open. Built from the push's `data` (the server repeats title,
/// body, tag, channel, link and the stay-on-screen flag there), falling back
/// to its `notification` block for pushes from older server versions.
class ForegroundAlert {
  const ForegroundAlert({
    required this.title,
    required this.body,
    required this.tag,
    required this.link,
    required this.sticky,
    required this.channel,
  });

  final String title;
  final String body;
  final String tag;
  final String link;
  final bool sticky;
  final String channel;

  /// Stable across app restarts (unlike String.hashCode), so a newer alert
  /// with the same [tag] replaces the older one in the Android tray.
  int get androidId {
    int hash = 0x811c9dc5;
    for (final int unit in tag.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

ForegroundAlert? foregroundAlertFrom(
  Map<String, dynamic> data, {
  String? notificationTitle,
  String? notificationBody,
}) {
  final String title = (data['title'] as String?) ?? notificationTitle ?? '';
  if (title.isEmpty) return null;
  final String? opportunityId = opportunityIdFromMessageData(data);
  final String type = (data['type'] as String?) ?? 'alert';
  final String channel = (data['channel'] as String?) ?? 'general';
  return ForegroundAlert(
    title: title,
    body: (data['body'] as String?) ?? notificationBody ?? '',
    tag:
        (data['tag'] as String?) ??
        (opportunityId != null ? 'opp-$opportunityId' : 'jva-$type'),
    link:
        (data['link'] as String?) ??
        (opportunityId != null
            ? '/?opportunityId=${Uri.encodeQueryComponent(opportunityId)}'
            : '/'),
    sticky: data['sticky'] == '1',
    channel: kAndroidChannels.containsKey(channel) ? channel : 'general',
  );
}

/// Handles a push that arrives while the app is fully backgrounded or
/// terminated, on Android/iOS (web uses `firebase-messaging-sw.js`).
/// Android/iOS display the `notification` payload themselves; this only
/// needs to exist so the plugin has a registered background handler.
///
/// Must be a top-level function: it runs in its own headless isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Wires up push display/navigation for every app state:
///
/// - **Closed / in the background**: the OS (Android) or the push service
///   worker (web) shows the notification itself; a tap opens the app on the
///   opportunity ([FirebaseMessaging.getInitialMessage] /
///   [FirebaseMessaging.onMessageOpenedApp] / the web `?opportunityId=` link).
/// - **Open**: FCM never displays anything itself while the app is open —
///   on web, even a visible tab hidden *behind* Outlook counts as open. So
///   the app shows a real system notification itself, exactly like a
///   background one: a Windows toast via the browser
///   ([showWebSystemNotification]) or an Android heads-up via
///   flutter_local_notifications. Tender/grant alerts stay on screen
///   (desktop) until clicked or dismissed. Only if that's impossible
///   (permission revoked, no service worker) does it fall back to an in-app
///   banner. iOS shows its own banner (presentation options below).
///
/// A plain class rather than a provider: it's set up once, at startup,
/// before sign-in.
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    // iOS hides notifications while the app is open unless told otherwise.
    // No-op on Android/web.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    if (_isAndroid) await _initLocalNotifications(navigatorKey);
    if (kIsWeb) {
      listenForWebNotificationClicks(
        (link) => _navigate(navigationDataFromLink(link), navigatorKey),
      );
    }

    FirebaseMessaging.onMessage.listen(
      (message) => _showForeground(message, navigatorKey),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigate(message.data, navigatorKey),
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(initialMessage.data, navigatorKey);
      return;
    }

    if (_localReady) {
      // App was started by tapping a foreground notification shown above.
      final NotificationAppLaunchDetails? launch = await _local
          .getNotificationAppLaunchDetails();
      final String? payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _navigateFromPayload(payload, navigatorKey),
        );
        return;
      }
    }

    // Web: a clicked browser notification opens the app at
    // `/?opportunityId=...` or `/?open=inbox`.
    if (kIsWeb) {
      final Map<String, dynamic> data = navigationDataFromLink(
        Uri.base.toString(),
      );
      if (data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _navigate(data, navigatorKey),
        );
      }
    }
  }

  Future<void> _initLocalNotifications(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_jva'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final String? payload = response.payload;
          if (payload != null) _navigateFromPayload(payload, navigatorKey);
        },
      );
      _localReady = true;
    } catch (e) {
      developer.log(
        'Local notifications unavailable',
        name: 'PushNotificationService',
        error: e,
      );
    }
  }

  Future<void> _showForeground(
    RemoteMessage message,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final ForegroundAlert? alert = foregroundAlertFrom(
      message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );
    if (alert == null) return;

    bool shown = false;
    if (kIsWeb) {
      shown = await showWebSystemNotification(
        title: alert.title,
        body: alert.body,
        tag: alert.tag,
        link: alert.link,
        sticky: alert.sticky,
      );
    } else if (_localReady) {
      shown = await _showAndroid(alert, message.data);
    }
    if (shown) return;
    _showForegroundBanner(alert, message.data, navigatorKey);
  }

  Future<bool> _showAndroid(
    ForegroundAlert alert,
    Map<String, dynamic> data,
  ) async {
    try {
      await _local.show(
        id: alert.androidId,
        title: alert.title,
        body: alert.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            alert.channel,
            kAndroidChannels[alert.channel] ?? 'Other alerts',
            importance: alert.channel == 'summary'
                ? Importance.defaultImportance
                : Importance.high,
            priority: alert.channel == 'summary'
                ? Priority.defaultPriority
                : Priority.high,
            icon: 'ic_stat_jva',
            color: const Color(0xFF1A2B4C),
            tag: alert.tag,
            styleInformation: BigTextStyleInformation(alert.body),
          ),
        ),
        payload: jsonEncode(<String, String>{
          for (final MapEntry<String, dynamic> e in data.entries)
            if (e.value is String) e.key: e.value as String,
        }),
      );
      return true;
    } catch (e) {
      developer.log(
        'Showing an Android notification failed',
        name: 'PushNotificationService',
        error: e,
      );
      return false;
    }
  }

  /// Fallback when no system notification could be shown: a prominent
  /// in-app banner with a button straight to the tender.
  void _showForegroundBanner(
    ForegroundAlert alert,
    Map<String, dynamic> data,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final bool canOpen =
        opportunityIdFromMessageData(data) != null || data['open'] == 'inbox';
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
              alert.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            if (alert.body.isNotEmpty)
              Text(
                alert.body,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
          if (canOpen)
            FilledButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _navigate(data, navigatorKey);
              },
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }

  void _navigateFromPayload(
    String payload,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map) {
        _navigate(Map<String, dynamic>.from(decoded), navigatorKey);
      }
    } catch (_) {
      // Malformed payload: nothing to open.
    }
  }

  void _navigate(
    Map<String, dynamic> data,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    // Weekly summary: back to the main screen, on the Opportunity Inbox.
    if (data['open'] == 'inbox') {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      openOpportunityInbox(ProviderScope.containerOf(context, listen: false));
      return;
    }

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
