import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/firebase_options.dart';
import 'package:jva_projecttracker/screens/shared/auth_gate.dart';
import 'package:jva_projecttracker/services/core/navigation_keys.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/push_notification_service.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Registered in Firebase Console > App Check > Apps > (web app) > reCAPTCHA.
const _recaptchaV3SiteKey = '6LfKkmEtAAAAACrWfNaSoMTYcvzNMsPlUTE0ltmv';

const supportedLocales = [Locale('en'), Locale('it')];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required before any DateFormat call that names a locale explicitly
  // (e.g. `DateFormat.yMMMd(strings.locale.toString())`, used by the
  // Experience and Opportunity Pipeline date pickers) — without this,
  // intl throws LocaleDataException at the first such call.
  for (final locale in supportedLocales) {
    await initializeDateFormatting(locale.languageCode);
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Must be registered before runApp — this is what lets Android/iOS wake a
  // headless isolate to run background push handling while the app is fully
  // terminated. See push_notification_service.dart's doc comment for why
  // this alone doesn't handle foreground/backgrounded display too.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Web has no local Firestore cache by default, so every screen
  // (e.g. the Project Workspace's Timeline/Deliverables/Risks/Activity
  // subsections, each its own `StreamProvider.family`) re-fetches from the
  // network on every navigation. Persistence lets repeat visits serve from
  // the local cache instantly while Firestore syncs any changes in the
  // background — same mechanism `cloud_firestore` already uses by default
  // on mobile, just not on web.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(_recaptchaV3SiteKey),
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
  final prefs = await SharedPreferences.getInstance();
  // Foreground banner + background/terminated tap deep-linking — see
  // PushNotificationService's doc comment for why each app state needs its
  // own handling. Safe to start before the first frame renders: its
  // listeners no-op harmlessly until `rootNavigatorKey` actually has a
  // mounted Navigator under it.
  unawaited(
    PushNotificationService().initialize(navigatorKey: rootNavigatorKey),
  );
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const JvaProjectTrackerApp(),
    ),
  );
}

class JvaProjectTrackerApp extends ConsumerWidget {
  const JvaProjectTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final font = ref.watch(appFontProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'JVA Project Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(font: font),
      darkTheme: AppTheme.dark(font: font),
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
