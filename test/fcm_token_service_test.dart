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
    'saves the token at users/{uid}/fcmTokens/{token} when permission is authorized',
    () async {
      final service = FcmTokenService(
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => 'token-abc',
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');

      final doc = await firestore
          .collection('users')
          .doc('user-1')
          .collection('fcmTokens')
          .doc('token-abc')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['token'], 'token-abc');
      expect(doc.data()!['updatedAt'], isNotNull);
    },
  );

  test('saves the token when permission is provisional', () async {
    final service = FcmTokenService(
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.provisional),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final doc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .doc('token-abc')
        .get();
    expect(doc.exists, isTrue);
  });

  test('does not save any token when permission is denied', () async {
    final service = FcmTokenService(
      firestore: firestore,
      requestPermission: () async => buildSettings(AuthorizationStatus.denied),
      getToken: () async => 'token-abc',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await service.requestPermissionAndSaveToken('user-1');

    final tokens = await firestore
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .get();
    expect(tokens.docs, isEmpty);
  });

  test(
    'does not save any token when authorized but getToken returns null (e.g. web without a VAPID key)',
    () async {
      final service = FcmTokenService(
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => null,
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');

      final tokens = await firestore
          .collection('users')
          .doc('user-1')
          .collection('fcmTokens')
          .get();
      expect(tokens.docs, isEmpty);
    },
  );

  test(
    'saving the same token twice for the same user overwrites rather than duplicating',
    () async {
      final service = FcmTokenService(
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => 'token-abc',
        onTokenRefresh: const Stream<String>.empty(),
      );

      await service.requestPermissionAndSaveToken('user-1');
      await service.requestPermissionAndSaveToken('user-1');

      final tokens = await firestore
          .collection('users')
          .doc('user-1')
          .collection('fcmTokens')
          .get();
      expect(tokens.docs, hasLength(1));
    },
  );

  test('two different users saving tokens do not clobber each other', () async {
    final serviceForUser1 = FcmTokenService(
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-user-1',
      onTokenRefresh: const Stream<String>.empty(),
    );
    final serviceForUser2 = FcmTokenService(
      firestore: firestore,
      requestPermission: () async =>
          buildSettings(AuthorizationStatus.authorized),
      getToken: () async => 'token-user-2',
      onTokenRefresh: const Stream<String>.empty(),
    );

    await serviceForUser1.requestPermissionAndSaveToken('user-1');
    await serviceForUser2.requestPermissionAndSaveToken('user-2');

    final user1Tokens = await firestore
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .get();
    final user2Tokens = await firestore
        .collection('users')
        .doc('user-2')
        .collection('fcmTokens')
        .get();
    expect(user1Tokens.docs.single.id, 'token-user-1');
    expect(user2Tokens.docs.single.id, 'token-user-2');
  });

  test('a token refresh saves the new token alongside the original', () async {
    final refreshController = StreamController<String>();
    addTearDown(refreshController.close);
    final service = FcmTokenService(
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
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .get();
    expect(
      tokens.docs.map((d) => d.id),
      containsAll(['token-original', 'token-refreshed']),
    );
  });

  test('deleteCurrentToken removes this device\'s token document', () async {
    var deleteTokenCalled = false;
    final service = FcmTokenService(
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
        .collection('users')
        .doc('user-1')
        .collection('fcmTokens')
        .get();
    expect(tokens.docs, isEmpty);
    expect(deleteTokenCalled, isTrue);
  });

  test(
    'deleteCurrentToken is a no-op when there is no current token',
    () async {
      final service = FcmTokenService(
        firestore: firestore,
        requestPermission: () async =>
            buildSettings(AuthorizationStatus.authorized),
        getToken: () async => null,
        onTokenRefresh: const Stream<String>.empty(),
        deleteToken: () async {},
      );

      await service.deleteCurrentToken('user-1');

      final tokens = await firestore
          .collection('users')
          .doc('user-1')
          .collection('fcmTokens')
          .get();
      expect(tokens.docs, isEmpty);
    },
  );
}
