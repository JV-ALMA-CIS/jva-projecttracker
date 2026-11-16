import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Registered in Firebase Console > Project Settings > Cloud Messaging > Web
/// Push certificates ("Generate key pair" if none exists yet). Required for
/// `getToken()` to return anything at all on web — without it, [getToken]
/// silently resolves to null and no web device ever receives a push. Same
/// "hardcoded public config value" convention as `main.dart`'s reCAPTCHA
/// site key: not a secret, just identifies this app's key pair to FCM.
const kFcmWebVapidKey =
    'BH8CI_iDTDm0W7AhqHKK5riT4j3mOlyyXMwMJ_yraA5K81COl3EASHQzh6hR_-Q0seAwRCnjwXL5nOx-4g4fIU0';

/// True once [kFcmWebVapidKey] holds a real key rather than the placeholder.
bool get isWebPushConfigured => !kFcmWebVapidKey.startsWith('REPLACE_ME');

/// Outcome of [FcmTokenService.sendTestNotification], for the Settings
/// screen to explain what happened.
enum TestNotificationOutcome {
  /// The push was accepted by FCM for at least one of the user's devices.
  sent,

  /// The user (or browser/OS) has blocked notifications for this app.
  permissionDenied,

  /// Web only: the VAPID key hasn't been configured, so this browser can't
  /// register for push at all.
  webPushNotConfigured,

  /// Permission is granted but no device token could be registered.
  noRegisteredDevice,

  /// FCM rejected the send for every registered device.
  deliveryFailed,
}

/// Requests notification permission, saves the device's FCM token so a
/// server-side push (see `functions/matchScorePushNotification.js`) has
/// somewhere to deliver to, keeps that token fresh for as long as the app is
/// running, and removes it again on sign-out.
///
/// One Firestore document per token at `users/{uid}/fcmTokens/{token}`
/// (token itself as the doc id) rather than a single field on the user
/// profile — a user may be signed in on more than one device, and each
/// device's token should be individually removable without clobbering
/// another device's entry.
class FcmTokenService {
  /// [requestPermission]/[getToken]/[onTokenRefresh]/[deleteToken] default
  /// to the real `FirebaseMessaging.instance` calls — overridable purely so
  /// tests can stub them out without needing a mockable `FirebaseMessaging`
  /// platform interface (unlike `firebase_auth`/`cloud_firestore`, there's
  /// no existing fake/mock convention for this package in this codebase
  /// yet). No production caller ever needs to pass these.
  FcmTokenService({
    FirebaseFirestore? firestore,
    Future<NotificationSettings> Function()? requestPermission,
    Future<String?> Function()? getToken,
    Stream<String>? onTokenRefresh,
    Future<void> Function()? deleteToken,
    Future<Map<String, dynamic>> Function()? callSendTestNotification,
  }) : _callSendTestNotificationOverride = callSendTestNotification,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _requestPermission =
           requestPermission ?? FirebaseMessaging.instance.requestPermission,
       _getToken =
           getToken ??
           (() => FirebaseMessaging.instance.getToken(
             vapidKey: kIsWeb ? kFcmWebVapidKey : null,
           )),
       _onTokenRefreshOverride = onTokenRefresh,
       _deleteTokenOverride = deleteToken;

  final FirebaseFirestore _firestore;
  final Future<NotificationSettings> Function() _requestPermission;
  final Future<String?> Function() _getToken;

  // Not resolved to a `FirebaseMessaging.instance` default in the
  // initializer list (unlike [_requestPermission]/[_getToken] above): both
  // are only ever touched from [requestPermissionAndSaveToken]/
  // [deleteCurrentToken], never from a plain constructor call, so evaluating
  // `FirebaseMessaging.instance` here unconditionally would make even a
  // test that overrides every other collaborator require a real Firebase
  // app just to construct this service.
  final Stream<String>? _onTokenRefreshOverride;
  final Future<void> Function()? _deleteTokenOverride;

  Stream<String> get _onTokenRefresh =>
      _onTokenRefreshOverride ?? FirebaseMessaging.instance.onTokenRefresh;
  Future<void> Function() get _deleteToken =>
      _deleteTokenOverride ?? FirebaseMessaging.instance.deleteToken;

  bool _refreshListenerAttached = false;

  CollectionReference<Map<String, dynamic>> _tokensCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens');

  /// Requests notification permission (a no-op on platforms/browsers that
  /// don't prompt) and, if granted, saves the current device token and
  /// starts forwarding any future token refresh (FCM rotates tokens
  /// periodically — e.g. after an app reinstall, cleared app data, or on its
  /// own schedule; an unforwarded refresh would silently leave a stale,
  /// undeliverable token as the only one on file) to the same
  /// `users/{uid}/fcmTokens` collection. Silent no-op if permission is
  /// denied or no token is available (e.g. web without a configured VAPID
  /// key, or a simulator).
  ///
  /// Safe to call more than once per app run (e.g. `AuthGate` re-invoking it
  /// is guarded elsewhere, but nothing here relies on that): the refresh
  /// listener is only ever attached once per [FcmTokenService] instance.
  Future<void> requestPermissionAndSaveToken(String uid) async {
    await _registerDevice(uid);
  }

  /// Does the work of [requestPermissionAndSaveToken] and reports why
  /// registration stopped, if it did. Returns null on success.
  Future<TestNotificationOutcome?> _registerDevice(String uid) async {
    final settings = await _requestPermission();
    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!authorized) return TestNotificationOutcome.permissionDenied;

    // Without a real VAPID key the browser can't register for push at all;
    // calling getToken would only throw. Skip quietly — see kFcmWebVapidKey.
    if (kIsWeb && !isWebPushConfigured) {
      developer.log(
        'Web push disabled: kFcmWebVapidKey is still the placeholder.',
        name: 'FcmTokenService',
      );
      return TestNotificationOutcome.webPushNotConfigured;
    }

    final token = await _getToken();
    if (token == null) return TestNotificationOutcome.noRegisteredDevice;
    await _saveToken(uid, token);

    if (!_refreshListenerAttached) {
      _refreshListenerAttached = true;
      _onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    }
    return null;
  }

  final Future<Map<String, dynamic>> Function()?
  _callSendTestNotificationOverride;

  Future<Map<String, dynamic>> _callSendTestNotification() async {
    final override = _callSendTestNotificationOverride;
    if (override != null) return override();
    final result = await FirebaseFunctions.instance
        .httpsCallable('sendTestNotification')
        .call<Map<String, dynamic>>();
    return Map<String, dynamic>.from(result.data);
  }

  /// Registers this device (asking for permission if needed), then asks the
  /// `sendTestNotification` Cloud Function to push a test notification to
  /// every device the signed-in user has registered. Lets each person confirm
  /// alerts actually reach their phone/browser.
  Future<TestNotificationOutcome> sendTestNotification(String uid) async {
    final registrationProblem = await _registerDevice(uid);
    if (registrationProblem != null) return registrationProblem;

    final result = await _callSendTestNotification();
    final tokenCount = (result['tokenCount'] as num?)?.toInt() ?? 0;
    final successCount = (result['successCount'] as num?)?.toInt() ?? 0;
    if (tokenCount == 0) return TestNotificationOutcome.noRegisteredDevice;
    if (successCount == 0) return TestNotificationOutcome.deliveryFailed;
    return TestNotificationOutcome.sent;
  }

  Future<void> _saveToken(String uid, String token) {
    return _tokensCollection(
      uid,
    ).doc(token).set({'token': token, 'updatedAt': Timestamp.now()});
  }

  /// Removes this device's token from `users/{uid}/fcmTokens` and tells FCM
  /// to discard it, called on sign-out. Without this, a signed-out device
  /// would keep receiving pushes meant for whichever admin account is
  /// signed in on it next (see `collectRecipientTokens` in
  /// `matchScorePushNotification.js`, which broadcasts to every admin's
  /// saved tokens) — a real leak on a shared/handed-down device. Best-effort:
  /// swallows failures since a sign-out must never be blocked by cleanup of
  /// data that will simply go stale and stop mattering once the account
  /// itself is signed out.
  Future<void> deleteCurrentToken(String uid) async {
    try {
      final token = await _getToken();
      if (token != null) {
        await _tokensCollection(uid).doc(token).delete();
      }
      await _deleteToken();
    } catch (_) {
      // Best-effort cleanup — see doc comment.
    }
  }
}
