// Firebase Cloud Messaging service worker — required for web push to be
// delivered while this app's tab is backgrounded or fully closed. Without
// this file registered, `FirebaseMessaging.instance.getToken()` in
// fcm_token_service.dart can still return a token (given a configured VAPID
// key), but no push will ever actually reach the browser outside an open,
// foregrounded tab, since there is nothing else to receive it.
//
// Lives at the web app's root and is registered (web/index.html, and by the
// Firebase Messaging SDK itself) in the "/firebase-cloud-messaging-push-scope"
// scope — not "/", which belongs to Flutter's own service worker.
//
// Uses the Firebase compat SDK (not the modular API) because service
// workers can't use bundler-style ES module imports here — this is
// Firebase's own documented pattern for this file.
importScripts(
  "https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js",
);

// Mirrors lib/firebase_options.dart's `web` FirebaseOptions. This file is
// NOT covered by `flutterfire configure` — if that command is re-run with a
// different Firebase project, update these values here too, by hand.
firebase.initializeApp({
  apiKey: "AIzaSyCgV4G_eej_dGWbMyaaF-W9C8cINJjpusw",
  appId: "1:331812083332:web:2a99e73470b4c7d46154d1",
  messagingSenderId: "331812083332",
  projectId: "jva-projecttracker",
  authDomain: "jva-projecttracker.firebaseapp.com",
  storageBucket: "jva-projecttracker.firebasestorage.app",
});

// Initializing messaging is all this file needs to do. For pushes that carry
// a `notification` payload (every push this app sends — see
// functions/matchScorePushNotification.js buildNotificationMessage), the
// Firebase SDK displays the notification itself and, on click, opens/focuses
// `webpush.fcmOptions.link` (the app URL with ?opportunityId=..., which
// PushNotificationService reads on startup to deep-link).
//
// Do NOT add an onBackgroundMessage handler that calls showNotification: the
// SDK already displays background pushes, so every push would appear twice.
firebase.messaging();

// Clicks on notifications the APP shows itself while it's open (see
// lib/services/web_system_notifier_web.dart — the SDK hands pushes to a
// visible tab instead of displaying them). Those carry `data.jvaLink`; the
// SDK's own notifications carry `data.FCM_MSG` and are left to the SDK's
// handler (registered by firebase.messaging() above), so nothing is handled
// twice. Focuses an open app tab and asks it to open the link in place;
// opens a new tab only if none is open.
self.addEventListener("notificationclick", (event) => {
  const link = event.notification?.data?.jvaLink;
  if (!link) return;
  event.notification.close();
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      const appTab = windows.find((c) => c.url.startsWith(self.location.origin));
      if (appTab) {
        await appTab.focus();
        appTab.postMessage({ jvaOpen: link });
        return;
      }
      await self.clients.openWindow(link);
    })(),
  );
});
