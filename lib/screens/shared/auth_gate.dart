import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/auth/sign_in_screen.dart';
import 'package:jva_projecttracker/screens/auth/sign_up_screen.dart';
import 'package:jva_projecttracker/screens/auth/welcome_screen.dart';
import 'package:jva_projecttracker/screens/shared/home_shell.dart';
import 'package:jva_projecttracker/services/auth_landing.dart';
import 'package:jva_projecttracker/services/providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final strings = ref.watch(appStringsProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Reset landing for the next sign-out, deferred so this doesn't
          // trigger a provider update while AuthGate itself is building.
          Future.microtask(
            () => ref.read(authLandingProvider.notifier).landing =
                AuthLanding.welcome,
          );
          return const HomeShell();
        }
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
