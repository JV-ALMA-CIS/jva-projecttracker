// Firebase Cloud Messaging service worker — required for web push to be
// delivered while this app's tab is backgrounded or fully closed. Without
// this file registered, `FirebaseMessaging.instance.getToken()` in
// fcm_token_service.dart can still return a token (given a configured VAPID
// key), but no push will ever actually reach the browser outside an open,
// foregrounded tab, since there is nothing else to receive it.
//
// Must live at the web app's root (not under a subfolder) so its default
// scope covers the whole origin. Registered from web/index.html.
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

const messaging = firebase.messaging();

// Background/closed-tab display: FCM's `notification` payload is normally
// shown automatically by the browser, but Chrome only does this reliably
// when a service worker explicitly handles `onBackgroundMessage` — without
// it, some browsers silently drop the notification instead of showing it.
// Clicking it focuses/opens the app; the deep link itself (which opportunity
// to open) is handled app-side via `onMessageOpenedApp`/`getInitialMessage`
// in push_notification_service.dart once the data payload's `opportunityId`
// reaches the running app, since a service worker cannot use app routing.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || "JVA Project Tracker";
  const body = payload.notification?.body;
  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    data: payload.data,
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ("focus" in client) return client.focus();
        }
        if (self.clients.openWindow) return self.clients.openWindow("/");
      }),
  );
});
