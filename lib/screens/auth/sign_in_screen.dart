import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/auth_landing.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Credentials only. Branding lives on [WelcomeScreen].
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .signIn(_emailController.text, _passwordController.text);
      // AuthGate watches authStateChangesProvider and swaps straight to
      // HomeShell once Firebase reports the signed-in user — no navigation
      // needed here.
    } on FirebaseAuthException catch (e) {
      _log.w('Sign-in failed', error: e);
      setState(() => _errorMessage = _messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final strings = ref.read(appStringsProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = strings.enterEmailFirst);
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.passwordResetSent(email))),
        );
      }
    } on FirebaseAuthException catch (e) {
      _log.w('Password reset failed', error: e);
      setState(() => _errorMessage = _messageForError(e));
    }
  }

  String _messageForError(FirebaseAuthException e) {
    final strings = ref.read(appStringsProvider);
    switch (e.code) {
      case 'invalid-email':
        return strings.invalidEmail;
      case 'user-disabled':
        return strings.accountDisabled;
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return strings.incorrectCredentials;
      default:
        return e.message ?? strings.signInFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.signInButton),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(authLandingProvider.notifier).landing =
              AuthLanding.welcome,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sign in to continue to your workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.fieldEmail,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? strings.emailRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: strings.fieldPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? strings.passwordRequired
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadii.input),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings.signInButton),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _submitting ? null : _resetPassword,
                    child: Text(strings.forgotPassword),
                  ),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => ref.read(authLandingProvider.notifier).landing =
                              AuthLanding.signUp,
                    child: Text(strings.createAccountButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
