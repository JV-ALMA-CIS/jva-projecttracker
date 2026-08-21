import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/auth_landing.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// First screen when signed out. Brand / story only — no credentials.
/// Frequent users still only see this when logged out; after sign-in they
/// go straight to the shell on next launch.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _ambient;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _bodyOpacity;
  late final Animation<double> _ctaOpacity;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();

    _ambient = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);

    _logoOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _logoScale = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );
    _titleOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    _bodyOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
    );
    _ctaOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_entry, _ambient]),
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.seedColor,
                  Color.lerp(AppTheme.seedColor, scheme.primary, 0.3)!,
                  Color.lerp(
                    AppTheme.seedColor,
                    const Color(0xFF0D4F4F),
                    0.45,
                  )!,
                ],
              ),
            ),
            child: Stack(
              children: [
                ..._ambientMarks(context),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Opacity(
                          opacity: _logoOpacity.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: math.max(0.0, _logoScale.value),
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.account_tree_outlined,
                                size: 44,
                                color: AppTheme.seedColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Opacity(
                          opacity: _titleOpacity.value.clamp(0.0, 1.0),
                          child: Text(
                            strings.appTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Opacity(
                          opacity: _bodyOpacity.value.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              Text(
                                'Projects · Tenders · Company intelligence',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Track past performance, discover opportunities, '
                                'and keep delivery work in one place for your team.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: const [
                                  _WelcomeChip(
                                    icon: Icons.work_outline,
                                    label: 'Projects',
                                  ),
                                  _WelcomeChip(
                                    icon: Icons.travel_explore_outlined,
                                    label: 'Opportunities',
                                  ),
                                  _WelcomeChip(
                                    icon: Icons.hub_outlined,
                                    label: 'Intelligence',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 3),
                        Opacity(
                          opacity: _ctaOpacity.value.clamp(0.0, 1.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.seedColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                ),
                                onPressed: () =>
                                    ref
                                            .read(authLandingProvider.notifier)
                                            .landing =
                                        AuthLanding.signIn,
                                child: Text(strings.signInButton),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                ),
                                onPressed: () =>
                                    ref
                                            .read(authLandingProvider.notifier)
                                            .landing =
                                        AuthLanding.signUp,
                                child: Text(strings.createAccountButton),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _ambientMarks(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return List.generate(6, (i) {
      final phase = (_ambient.value + i * 0.14) % 1.0;
      final dy = math.sin(phase * math.pi) * 10;
      return Positioned(
        left: (size.width * 0.1) + (i % 3) * (size.width * 0.28),
        top: 40.0 + i * 48 + dy,
        child: Opacity(
          opacity: 0.1 + (i % 3) * 0.03,
          child: Icon(
            i.isEven ? Icons.hexagon_outlined : Icons.apartment_outlined,
            color: Colors.white,
            size: 20.0 + (i % 3) * 6,
          ),
        ),
      );
    });
  }
}

class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
