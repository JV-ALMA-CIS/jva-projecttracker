import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_font.dart';

/// Spacing scale used across the app instead of raw [EdgeInsets]/[SizedBox]
/// literals, so vertical/horizontal rhythm stays consistent.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale used across cards, inputs, and chips.
class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double chip = 20;
  static const double input = 12;
}

/// Shared animation durations/curves — the platform's one motion system.
/// Screens should reach for these instead of inventing their own
/// `Duration(milliseconds: ...)` literals, so a future pacing change (faster/
/// slower overall feel) only has to happen here. [HoverLift] and
/// [SlideFadePageRoute] predate this and use their own literals close to
/// these values; left as-is rather than churned for a cosmetic-only rename.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
}

/// Centralized semantic status colors — the platform's one status-color
/// system, consolidating what was already consistently chosen (just
/// scattered) across `priority_style.dart`, `submission_status_style.dart`,
/// and `fit_score_color`: green for healthy/positive outcomes, amber for
/// "worth watching," red for critical/overdue, blue for neutral/
/// informational, indigo reserved for AI/intelligence content specifically
/// (never reused for a non-AI status, so an indigo accent always means
/// "this came from the AI layer"). Screens should read these roles rather
/// than reaching for `Colors.orange`/`Colors.red` directly.
class AppStatusColors {
  const AppStatusColors._();

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);
  static const Color ai = Color(0xFF5E35B1);
}

/// Central theme definition. Keeping this in one place means every screen
/// picks up the same look with zero per-widget styling.
class AppTheme {
  const AppTheme._();

  /// Deep navy — the platform's brand/primary seed. `ColorScheme.fromSeed`
  /// derives every primary/secondary/tertiary role from this one value, so
  /// changing the brand color is a one-line edit, never a per-widget hunt.
  /// (Previously a green seed; green now lives solely in
  /// [AppStatusColors.success] so "success" and "brand" read as distinct
  /// signals instead of the same color meaning two different things.)
  static const Color seedColor = Color(0xFF1A2B4C);

  static ThemeData light({AppFont font = AppFont.roboto}) =>
      _build(Brightness.light, font);

  static ThemeData dark({AppFont font = AppFont.roboto}) =>
      _build(Brightness.dark, font);

  static ThemeData _build(Brightness brightness, AppFont font) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      // Tertiary carries the AI/intelligence accent throughout the app
      // (AI recommendation cards, AI-generated summaries, extraction
      // status) — distinct from primary (brand/navigation) and secondary
      // (derived success-adjacent tone), so "this came from the AI layer"
      // has exactly one visual signature app-wide.
      tertiary: AppStatusColors.ai,
    );
    final base = ThemeData(brightness: brightness);
    final textTheme = font.apply(base.textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      dividerTheme: DividerThemeData(
        space: AppSpacing.lg,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadii.input * 0.6),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(AppRadii.chip),
        thumbColor: WidgetStateProperty.all(
          colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
