import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/fcm_token_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  NotificationSettings buildSettings(AuthorizationStatus status) {
    return NotificationSettings(
      authorizationStatus: status,
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );
  }

  test(
    'saves the token at deviceTokens/{token} with owner, platform and OS when permission is authorized',
    () async {
      final service = FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => 'token-abc',
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');

      final doc = await firestore
          .collection('deviceTokens')
          .doc('token-abc')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['token'], 'token-abc');
      expect(doc.data()!['updatedAt'], isNotNull);
      expect(doc.data()!['uid'], 'user-1');
      expect(doc.data()!['platform'], 'web');
      expect(doc.data()!['os'], 'windows');
    },
  );

  test('saves the token when permission is provisional', () async {
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.provisional),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final doc = await firestore
        .collection('deviceTokens')
        .doc('token-abc')
        .get();
    expect(doc.exists, isTrue);
  });

  test('does not save any token when permission is denied', () async {
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async => buildSettings(AuthorizationStatus.denied),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final tokens = await firestore
        .collection('deviceTokens')
        .where('uid', isEqualTo: 'user-1')
        .get();
    expect(tokens.docs, isEmpty);
  });

  test(
    'does not save any token when authorized but getToken returns null (e.g. web without a VAPID key)',
    () async {
      final service = FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => null,
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');

      final tokens = await firestore
          .collection('deviceTokens')
          .where('uid', isEqualTo: 'user-1')
          .get();
      expect(tokens.docs, isEmpty);
    },
  );

  test(
    'saving the same token twice for the same user overwrites rather than duplicating',
    () async {
      final service = FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => 'token-abc',
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');
      await service.requestPermissionAndSaveToken('user-1');

      final tokens = await firestore
          .collection('deviceTokens')
          .where('uid', isEqualTo: 'user-1')
          .get();
      expect(tokens.docs, hasLength(1));
    },
  );

  test('two different users saving tokens do not clobber each other', () async {
    final serviceForUser1 = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-user-1',
      onTokenRefresh: const Stream<String>.empty(),
    );
    final serviceForUser2 = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-user-2',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await serviceForUser1.requestPermissionAndSaveToken('user-1');
    await serviceForUser2.requestPermissionAndSaveToken('user-2');

    final user1Tokens = await firestore
        .collection('deviceTokens')
        .where('uid', isEqualTo: 'user-1')
        .get();
    final user2Tokens = await firestore
        .collection('deviceTokens')
        .where('uid', isEqualTo: 'user-2')
        .get();
    expect(user1Tokens.docs.single.id, 'token-user-1');
    expect(user2Tokens.docs.single.id, 'token-user-2');
  });

  test('a token refresh saves the new token alongside the original', () async {
    final refreshController = StreamController<String>();
    addTearDown(refreshController.close);
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-original',
      onTokenRefresh: refreshController.stream,
    );

    await service.requestPermissionAndSaveToken('user-1');
    refreshController.add('token-refreshed');
    await Future<void>.delayed(Duration.zero);

    final tokens = await firestore
        .collection('deviceTokens')
        .where('uid', isEqualTo: 'user-1')
        .get();
    expect(
      tokens.docs.map((d) => d.id),
      containsAll(['token-original', 'token-refreshed']),
    );
  });

  test('deleteCurrentToken removes this device\'s token document', () async {
    var deleteTokenCalled = false;
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
      deleteToken: () async => deleteTokenCalled = true,
    );

    await service.requestPermissionAndSaveToken('user-1');
    await service.deleteCurrentToken('user-1');

    final tokens = await firestore
        .collection('deviceTokens')
        .where('uid', isEqualTo: 'user-1')
        .get();
    expect(tokens.docs, isEmpty);
    expect(deleteTokenCalled, isTrue);
  });

  test(
    'deleteCurrentToken is a no-op when there is no current token',
    () async {
      final service = FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => null,
        onTokenRefresh: const Stream<String>.empty(),
        deleteToken: () async {},
      );

      await service.deleteCurrentToken('user-1');

      final tokens = await firestore
          .collection('deviceTokens')
          .where('uid', isEqualTo: 'user-1')
          .get();
      expect(tokens.docs, isEmpty);
    },
  );

  test(
    'a device re-registered by another account moves to that account',
    () async {
      FcmTokenService forUser(String uid) => FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => 'shared-pc',
        onTokenRefresh: const Stream<String>.empty(),
      );

      await forUser('user-1').requestPermissionAndSaveToken('user-1');
      await forUser('user-2').requestPermissionAndSaveToken('user-2');

      final doc = await firestore
          .collection('deviceTokens')
          .doc('shared-pc')
          .get();
      expect(doc.data()!['uid'], 'user-2');
    },
  );

  test('registering removes this device\'s old-location copy', () async {
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .doc('token-abc')
        .set({'token': 'token-abc'});
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final legacy = await firestore
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .get();
    expect(legacy.docs, isEmpty);
    expect(service.currentToken, 'token-abc');
  });

  test('retries when getting the token fails, then registers', () async {
    int calls = 0;
    final List<Duration> waits = [];
    final service = FcmTokenService(
      platform: 'android',
      os: 'android',
      delay: (d) async => waits.add(d),
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async {
        calls++;
        if (calls < 3) throw Exception('offline');
        return 'token-late';
      },
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    expect(waits, kRegistrationRetryDelays.take(2).toList());
    final doc = await firestore
        .collection('deviceTokens')
        .doc('token-late')
        .get();
    expect(doc.data()!['platform'], 'android');
  });

  test('gives up quietly after the last retry', () async {
    final service = FcmTokenService(
      platform: 'web',
      os: 'windows',
      delay: (_) async {},
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => throw Exception('offline'),
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final tokens = await firestore.collection('deviceTokens').get();
    expect(tokens.docs, isEmpty);
  });

  test('watchMyDevices lists only the signed-in person\'s devices', () async {
    await firestore.collection('deviceTokens').doc('a').set({
      'token': 'a',
      'uid': 'user-1',
      'platform': 'web',
      'os': 'windows',
    });
    await firestore.collection('deviceTokens').doc('b').set({
      'token': 'b',
      'uid': 'user-2',
      'platform': 'android',
      'os': 'android',
    });
    final service = FcmTokenService(
      firestore: firestore,
      platform: 'web',
      os: 'windows',
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => null,
    );

    final devices = await service.watchMyDevices('user-1').first;
    expect(devices.map((d) => d.token), ['a']);
  });

  group('sendTestNotification', () {
    FcmTokenService buildService({
      AuthorizationStatus status = AuthorizationStatus.authorized,
      String? token = 'token-abc',
      Map<String, dynamic> callResult = const {
        'tokenCount': 1,
        'successCount': 1,
        'failureCount': 0,
      },
      void Function()? onCall,
    }) {
      return FcmTokenService(
        platform: 'web',
        os: 'windows',
        delay: (_) async {},
        firestore: firestore,
        requestPermission: () async => buildSettings(status),
        getToken: () async => token,
        onTokenRefresh: const Stream<String>.empty(),
        callSendTestNotification: () async {
          onCall?.call();
          return callResult;
        },
      );
    }

    test('registers the device and reports sent on success', () async {
      final outcome = await buildService().sendTestNotification('user-1');

      expect(outcome, TestNotificationOutcome.sent);
      final doc = await firestore
          .collection('deviceTokens')
          .doc('token-abc')
          .get();
      expect(doc.exists, isTrue);
    });

    test('reports permissionDenied without calling the function', () async {
      var called = false;
      final outcome = await buildService(
        status: AuthorizationStatus.denied,
        onCall: () => called = true,
      ).sendTestNotification('user-1');

      expect(outcome, TestNotificationOutcome.permissionDenied);
      expect(called, isFalse);
    });

    test('reports noRegisteredDevice when no token is available', () async {
      final outcome = await buildService(
        token: null,
      ).sendTestNotification('user-1');

      expect(outcome, TestNotificationOutcome.noRegisteredDevice);
    });

    test('reports deliveryFailed when FCM rejects every device', () async {
      final outcome = await buildService(
        callResult: const {
          'tokenCount': 2,
          'successCount': 0,
          'failureCount': 2,
        },
      ).sendTestNotification('user-1');

      expect(outcome, TestNotificationOutcome.deliveryFailed);
    });
  });
}
