import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/auth/sign_in_screen.dart';
import 'package:jva_projecttracker/screens/auth/sign_up_screen.dart';
import 'package:jva_projecttracker/screens/auth/welcome_screen.dart';
import 'package:jva_projecttracker/screens/shared/home_shell.dart';
import 'package:jva_projecttracker/services/auth_landing.dart';
import 'package:jva_projecttracker/services/providers.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  // Guards both side effects below against firing again on every rebuild
  // while signed in (e.g. a locale/theme change elsewhere triggering a
  // rebuild of this widget) — only a genuine uid change (a real sign-in,
  // including switching accounts) should re-trigger them.
  String? _handledUid;

  void _handleSignedIn(String uid) {
    if (_handledUid == uid) return;
    _handledUid = uid;

    // Reset landing for the next sign-out, deferred so this doesn't trigger
    // a provider update while AuthGate itself is building.
    Future.microtask(
      () =>
          ref.read(authLandingProvider.notifier).landing = AuthLanding.welcome,
    );
    // Foundation for a future ≥70% match-score push — request permission
    // and save this device's FCM token now that we know who's signed in.
    // Fire-and-forget: a denied permission or a save failure shouldn't
    // block reaching HomeShell, and there's nothing actionable for the
    // user to do about it yet (no push feature exists to explain why
    // permission matters).
    Future.microtask(
      () =>
          ref.read(fcmTokenServiceProvider).requestPermissionAndSaveToken(uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final strings = ref.watch(appStringsProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          _handleSignedIn(user.uid);
          return const HomeShell();
        }
        _handledUid = null;
        final AuthLanding landing = ref.watch(authLandingProvider);
        return switch (landing) {
          AuthLanding.welcome => const WelcomeScreen(),
          AuthLanding.signIn => const SignInScreen(),
          AuthLanding.signUp => const SignUpScreen(),
        };
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(strings.authenticationError(e)))),
    );
  }
}
