import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:jva_projecttracker/models/device_registration.dart';

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

/// Top-level push device registry — see `functions/matchScorePushNotification.js`
/// `collectRecipientTokens`. Keep the name in sync with `DEVICE_TOKENS` there.
const kDeviceTokensCollection = 'deviceTokens';

/// Waits between registration retries when getting or saving the token
/// fails (offline at sign-in, a flaky network, ...).
const kRegistrationRetryDelays = <Duration>[
  Duration(seconds: 10),
  Duration(minutes: 1),
  Duration(minutes: 5),
];

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

/// Requests notification permission, registers this device in the
/// top-level `deviceTokens/{token}` registry (tagged with the owner's uid,
/// platform and OS) so the Cloud Functions can push to it, keeps that entry
/// fresh while the app runs, and removes it again on sign-out.
///
/// Why a top-level registry rather than `users/{uid}/fcmTokens/{token}`:
/// the server used to find devices by listing `users` docs first, and any
/// account without a profile doc was silently skipped. The registry is read
/// directly, so every signed-in device is reachable. Older app builds still
/// write the old location; the server moves those entries over on each send,
/// and this service deletes this device's old-location copy when it
/// re-registers.
class FcmTokenService {
  /// [requestPermission]/[getToken]/[onTokenRefresh]/[deleteToken] default
  /// to the real `FirebaseMessaging.instance` calls — overridable purely so
  /// tests can stub them out. [delay] is overridable so retry tests don't
  /// actually wait. No production caller ever needs to pass these.
  FcmTokenService({
    FirebaseFirestore? firestore,
    Future<NotificationSettings> Function()? requestPermission,
    Future<String?> Function()? getToken,
    Stream<String>? onTokenRefresh,
    Future<void> Function()? deleteToken,
    Future<Map<String, dynamic>> Function()? callSendTestNotification,
    Future<void> Function(Duration)? delay,
    String? platform,
    String? os,
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
       _deleteTokenOverride = deleteToken,
       _delay = delay ?? Future<void>.delayed,
       _platform = platform ?? (kIsWeb ? 'web' : defaultTargetPlatform.name),
       _os = os ?? defaultTargetPlatform.name;

  final FirebaseFirestore _firestore;
  final Future<NotificationSettings> Function() _requestPermission;
  final Future<String?> Function() _getToken;
  final Future<void> Function(Duration) _delay;
  final String _platform;
  final String _os;

  // Not resolved to a `FirebaseMessaging.instance` default in the
  // initializer list: both are only touched from registration/sign-out, so
  // a test that overrides every other collaborator doesn't need a real
  // Firebase app just to construct this service.
  final Stream<String>? _onTokenRefreshOverride;
  final Future<void> Function()? _deleteTokenOverride;

  Stream<String> get _onTokenRefresh =>
      _onTokenRefreshOverride ?? FirebaseMessaging.instance.onTokenRefresh;
  Future<void> Function() get _deleteToken =>
      _deleteTokenOverride ?? FirebaseMessaging.instance.deleteToken;

  StreamSubscription<String>? _refreshSubscription;
  String? _refreshUid;

  /// This device's token once registered in this app run, so Settings can
  /// mark "This device" in the device list. Null until registration succeeds.
  String? get currentToken => _currentToken;
  String? _currentToken;

  DocumentReference<Map<String, dynamic>> _deviceDoc(String token) =>
      _firestore.collection(kDeviceTokensCollection).doc(token);

  DocumentReference<Map<String, dynamic>> _legacyDoc(
    String uid,
    String token,
  ) => _firestore
      .collection('users')
      .doc(uid)
      .collection('fcmTokens')
      .doc(token);

  /// Live list of the signed-in person's registered devices (Settings →
  /// "My devices").
  Stream<List<DeviceRegistration>> watchMyDevices(String uid) {
    return _firestore
        .collection(kDeviceTokensCollection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final List<DeviceRegistration> devices = snap.docs
              .map((d) => DeviceRegistration.fromMap(d.id, d.data()))
              .toList();
          devices.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return devices;
        });
  }

  /// Requests permission (a no-op where the platform doesn't prompt) and, if
  /// granted, registers this device and forwards future token refreshes.
  /// If getting or saving the token fails (e.g. offline at sign-in), retries
  /// after each of [kRegistrationRetryDelays]. Never throws.
  Future<void> requestPermissionAndSaveToken(String uid) async {
    for (int attempt = 0; ; attempt++) {
      try {
        await _registerDevice(uid);
        return;
      } catch (e) {
        if (attempt >= kRegistrationRetryDelays.length) {
          developer.log(
            'Push registration failed after ${attempt + 1} attempts',
            name: 'FcmTokenService',
            error: e,
          );
          return;
        }
        developer.log(
          'Push registration failed; retrying',
          name: 'FcmTokenService',
          error: e,
        );
        await _delay(kRegistrationRetryDelays[attempt]);
      }
    }
  }

  /// Does the work of [requestPermissionAndSaveToken] once and reports why
  /// registration stopped, if it did. Returns null on success. Throws on
  /// network/Firestore errors so the caller can retry.
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
    _currentToken = token;

    if (_refreshUid != uid) {
      await _refreshSubscription?.cancel();
      _refreshUid = uid;
      _refreshSubscription = _onTokenRefresh.listen((newToken) async {
        try {
          await _saveToken(uid, newToken);
          _currentToken = newToken;
        } catch (e) {
          developer.log(
            'Saving refreshed token failed',
            name: 'FcmTokenService',
            error: e,
          );
        }
      });
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
  /// every device the signed-in user has registered.
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

  /// Writes (or re-claims) this device's registry entry — merge, so the
  /// server-written `lastSentAt` survives — then removes any old-location
  /// copy so the device isn't counted twice.
  Future<void> _saveToken(String uid, String token) async {
    await _deviceDoc(token).set({
      'token': token,
      'uid': uid,
      'platform': _platform,
      'os': _os,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await _legacyDoc(uid, token).delete();
    } catch (_) {
      // Best-effort: the server moves/dedupes old-location tokens anyway.
    }
  }

  /// Removes this device's registry entry (and any old-location copy) and
  /// tells FCM to discard the token, called on sign-out — must run before
  /// signOut(), while the rules still let this account delete it. Without
  /// this, a signed-out device would keep receiving the team's alerts.
  /// Best-effort: a sign-out must never be blocked by this cleanup.
  Future<void> deleteCurrentToken(String uid) async {
    try {
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
      _refreshUid = null;
      final token = _currentToken ?? await _getToken();
      if (token != null) {
        await _deviceDoc(token).delete();
        await _legacyDoc(uid, token).delete();
      }
      _currentToken = null;
      await _deleteToken();
    } catch (_) {
      // Best-effort cleanup — see doc comment.
    }
  }
}
