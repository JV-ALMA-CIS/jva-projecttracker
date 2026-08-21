import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthLanding { welcome, signIn, signUp }

/// Which signed-out screen AuthGate shows. Same shape as
/// [SelectedTabIndexController]/`ThemeModeController`: a `Notifier` with a
/// named setter, since Riverpod 3 removed `StateProvider` and made
/// `Notifier.state` write-protected to subclasses.
class AuthLandingNotifier extends Notifier<AuthLanding> {
  @override
  AuthLanding build() => AuthLanding.welcome;

  set landing(AuthLanding value) => state = value;
}

final authLandingProvider = NotifierProvider<AuthLandingNotifier, AuthLanding>(
  AuthLandingNotifier.new,
);
