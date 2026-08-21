import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/auth_landing.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final email = _emailController.text.trim();
      await ref
          .read(authServiceProvider)
          .signUp(email, _passwordController.text);
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(userServiceProvider).createOwnProfile(uid, email);
      // Sign-up doesn't sign the user in on some flows; land back on Sign
      // In. If Firebase did sign them in, AuthGate's authState listener
      // takes over and shows HomeShell regardless of landing.
      if (mounted) {
        ref.read(authLandingProvider.notifier).landing = AuthLanding.signIn;
      }
    } on FirebaseAuthException catch (e) {
      _log.w('Sign-up failed', error: e);
      setState(() => _errorMessage = _messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForError(FirebaseAuthException e) {
    final strings = ref.read(appStringsProvider);
    switch (e.code) {
      case 'email-already-in-use':
        return strings.emailAlreadyInUse;
      case 'invalid-email':
        return strings.invalidEmail;
      case 'weak-password':
        return strings.weakPassword;
      default:
        return e.message ?? strings.signUpFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.createAccountTitle),
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
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.person_add_outlined,
                        size: 32,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Create an account for your team workspace',
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
                    autofillHints: const [AutofillHints.newPassword],
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
                    validator: (v) => (v == null || v.length < 6)
                        ? strings.useAtLeast6Chars
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: strings.fieldConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => v != _passwordController.text
                        ? strings.passwordsDoNotMatch
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
                        : Text(strings.createAccountButton),
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
