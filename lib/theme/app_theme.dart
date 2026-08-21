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

/// Centralized semantic status/section colors — the platform's one
/// color-role system, consolidating what was already consistently chosen
/// (just scattered) across `priority_style.dart`,
/// `submission_status_style.dart`, `fit_score_color`, and various
/// screen-local `_kTabColors`/`_sectionDot` helpers: green for
/// healthy/positive outcomes, amber for "worth watching," red for
/// critical/overdue, blue for neutral/informational, purple reserved for
/// AI/intelligence content specifically (never reused for a non-AI status,
/// so a purple accent always means "this came from the AI layer"), teal for
/// operational/delivery work (Projects, Delivery & Wins), cyan for
/// technology-specific content (distinct from the more general `info`
/// blue), and a defined neutral for anything with no real status (replacing
/// ad-hoc `Colors.grey`/`Colors.blueGrey` literals). Screens should read
/// these roles rather than reaching for `Colors.orange`/`Colors.red`
/// directly — every hardcoded status color found during the design-system
/// audit (`pipeline_stage_badge.dart`, `submission_status_style.dart`) has
/// been remapped onto this table.
class AppStatusColors {
  const AppStatusColors._();

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);
  static const Color ai = Color(0xFF5E35B1);

  /// Operational/delivery work — active Projects, Delivery & Wins. Teal
  /// reads as "in motion, on the ground" without colliding with success
  /// (green, reserved for a *completed* positive outcome like Awarded) or
  /// info (blue, reserved for general discovery/informational content).
  static const Color operations = Color(0xFF00796B);

  /// Technology-specific content (tech stack chips, IT Business Unit
  /// accents) — distinct from [info] so "this is a technology" and "this is
  /// generic informational content" don't collapse into the same blue.
  static const Color technology = Color(0xFF0097A7);

  /// The one deliberate neutral — used in place of raw `Colors.grey`/
  /// `Colors.blueGrey` for a status that genuinely carries no signal (e.g.
  /// "Withdrawn," "Not Classified," a catch-all pipeline stage). Never used
  /// for text; see [AppTheme] for supporting-text color, which reads
  /// `colorScheme.onSurfaceVariant` instead so it stays theme- and
  /// brightness-aware.
  static const Color neutral = Color(0xFF607D8B);

  /// Low-alpha "container" tint of [color] — the one formula every status
  /// badge/chip/card accent in this app uses for its background fill, so a
  /// success/warning/danger/etc. badge always reads at the same visual
  /// weight regardless of which screen renders it.
  static Color container(Color color) => color.withValues(alpha: 0.12);
}

/// Categorical identity colors for Company Intelligence entity types —
/// deliberately a *separate* palette from [AppStatusColors]. AppStatusColors
/// answers "what state is this in" (healthy/watch/critical/AI-derived/
/// operational); AppEntityColors answers "what type of thing is this" and is
/// never used to convey status. The two never render in the same visual
/// slot: entity color drives icon chips, page/section accents, and a card's
/// identity stripe; status color still drives badges and health chips. Kept
/// out of AppStatusColors so a future status color never has to dodge nine
/// more reserved hues, and so "purple always means AI" (see
/// [AppStatusColors]'s doc comment) stays true without exception.
///
/// [technology] intentionally reuses [AppStatusColors.technology] rather
/// than introducing a competing cyan — the Technology entity type and
/// "tech-specific content" are the same concept everywhere else in the app,
/// so this is the one deliberate overlap.
class AppEntityColors {
  const AppEntityColors._();

  static const Color businessUnit = Color(0xFF3F51B5);
  static const Color product = Color(0xFFC2185B);
  static const Color service = Color(0xFF6D4C41);
  static const Color capability = Color(0xFFB8860B);
  static const Color technology = AppStatusColors.technology;
  static const Color industry = Color(0xFF55795A);
  static const Color experience = Color(0xFF8E3B46);
  static const Color knowledgeBase = Color(0xFFA65E2E);
  static const Color certification = Color(0xFF4A6FA5);
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
        // A hairline border (rather than raising elevation) gives cards a
        // visible edge against the scaffold background without adding
        // shadow noise — flat elevation-0 cards were reading as an
        // undifferentiated grey wall since only the very slight
        // surfaceContainerLow tint separated a card from the page.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
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
      // Baseline for every TabBar in the app (Opportunities' 3-tab strip,
      // the Company Intelligence sub-tabs, etc.): a visible indicator plus a
      // clear selected/unselected weight and opacity split, so a tab row
      // reads as interactive even before a screen adds its own per-tab
      // semantic accent color (see `opportunities_screen.dart`'s
      // `_kTabColors` — that per-tab coloring layers on top of, rather than
      // replaces, this baseline).
      tabBarTheme: TabBarThemeData(
        dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
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