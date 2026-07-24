import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/firebase_options.dart';
import 'package:jva_projecttracker/screens/shared/auth_gate.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

// Registered in Firebase Console > App Check > Apps > (web app) > reCAPTCHA.
const _recaptchaV3SiteKey = '6LfKkmEtAAAAACrWfNaSoMTYcvzNMsPlUTE0ltmv';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(_recaptchaV3SiteKey),
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
  runApp(const ProviderScope(child: JvaProjectTrackerApp()));
}

class JvaProjectTrackerApp extends StatelessWidget {
  const JvaProjectTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JVA Project Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}
