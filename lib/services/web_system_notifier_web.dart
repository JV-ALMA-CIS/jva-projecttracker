import 'dart:developer' as developer;
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Scope the push service worker is registered in (web/index.html and the
/// Firebase Messaging SDK both use it).
const String _pushScope = '/firebase-cloud-messaging-push-scope';

/// Shows a real operating-system notification from the browser (a Windows
/// toast / macOS banner), even while this tab is open and visible.
///
/// Why this is needed: when a push arrives and any tab of the app is
/// visible, the Firebase SDK hands it to the page instead of displaying it —
/// so someone with the tracker open behind Outlook would otherwise see
/// nothing. Shown through the push service worker's registration so the
/// click is handled there (`notificationclick` in firebase-messaging-sw.js),
/// which then asks this page to open [link] in place (see
/// [listenForWebNotificationClicks]). [sticky] keeps it on screen until the
/// person clicks or dismisses it. Returns false if it couldn't be shown
/// (permission not granted, no service worker) so the caller can fall back
/// to an in-app banner.
Future<bool> showWebSystemNotification({
  required String title,
  required String body,
  required String tag,
  required String link,
  required bool sticky,
}) async {
  try {
    if (web.Notification.permission != 'granted') return false;
    final web.NotificationOptions options = web.NotificationOptions(
      body: body,
      tag: tag,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      renotify: true,
      requireInteraction: sticky,
      data: <String, Object?>{'jvaLink': link}.jsify(),
    );
    final web.ServiceWorkerRegistration? registration = await web
        .window
        .navigator
        .serviceWorker
        .getRegistration(_pushScope)
        .toDart;
    if (registration == null) return false;
    await registration.showNotification(title, options).toDart;
    return true;
  } catch (e) {
    developer.log(
      'Showing a browser notification failed',
      name: 'WebSystemNotifier',
      error: e,
    );
    return false;
  }
}

/// Calls [onOpen] with the notification's link when the person clicks a
/// notification shown by [showWebSystemNotification] and this tab is the
/// one the service worker focused (it posts `{jvaOpen: link}` to it).
void listenForWebNotificationClicks(void Function(String link) onOpen) {
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.MessageEvent event) {
        final Object? data = event.data.dartify();
        if (data is Map && data['jvaOpen'] is String) {
          onOpen(data['jvaOpen'] as String);
        }
      }).toJS,
    );
  } catch (e) {
    developer.log(
      'Listening for notification clicks failed',
      name: 'WebSystemNotifier',
      error: e,
    );
  }
}
