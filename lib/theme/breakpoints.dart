/// Window-size breakpoints used across the app's shared layout shell
/// (`PageHeader`, `HomeShell`, `AppSidebar`, `StatCardRow`, etc.) so every
/// screen responds to the same set of width thresholds instead of each
/// picking its own cutoff.
///
/// Two cutoffs (`compact`/`medium`) used to be all this had — a strict
/// "mobile vs. tablet vs. desktop" split. That's too coarse in practice: a
/// small phone (iPhone SE, ~375dp) and a large phone (Pro Max, ~430dp) both
/// landed in the same "compact" bucket even though titles/icons that fit
/// comfortably on the larger one visibly crowd on the smaller one; a 14"
/// laptop window (~1280-1366dp) and a 16" one (~1728dp+) both landed in the
/// same "expanded" bucket even though the sidebar/content ratio that looks
/// right on the larger one can feel cramped on the smaller one. The finer
/// scale below exists so call sites that care (mainly `PageHeader`) can
/// step down icon/text sizing gradually across a real window, not jump
/// between two fixed looks.
///
/// All values are in density-independent pixels (`MediaQuery` logical
/// width), matching Flutter's own convention (a "phone" and "desktop
/// window" are compared on the same logical-pixel scale, not physical
/// screen inches).
class AppBreakpoints {
  const AppBreakpoints._();

  /// Below this: a small phone (iPhone SE/Mini-class, ~360-390dp). Tightest
  /// layout — smallest header icon/type, no back-button label, single
  /// column everywhere StatCardRow-style widgets would otherwise wrap to 2.
  static const double smallPhone = 380;

  /// Below this (and at/above [smallPhone]): a typical large phone
  /// (~391-599dp). Same single-column layout as [smallPhone] but with a
  /// touch more breathing room in header sizing.
  static const double compact = 600;

  /// Below this (and at/above [compact]): a tablet in portrait, or a phone
  /// in landscape.
  static const double medium = 1024;

  /// At/above this (and below [largeDesktop]): a small/14" laptop window
  /// (~1024-1365dp) — sidebar starts collapsed-to-icons by default here
  /// rather than immediately going extended, since a 240dp extended rail
  /// takes a visibly larger bite out of a 1280dp window than a 1728dp one.
  static const double smallDesktop = 1024;

  /// At/above this: a large desktop/16"+ window — the sidebar is extended
  /// and headers use their largest, most spacious sizing.
  static const double largeDesktop = 1366;
}
