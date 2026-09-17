/// Continuous, width-driven scaling for the shared layout shell
/// (`PageHeader`, `AppSidebar`, `HomeShell`, `StatCardRow`).
///
/// The old approach picked from a small, fixed set of layouts based on
/// which named breakpoint bucket the current width fell into ("compact",
/// "medium", "expanded" — see `breakpoints.dart`'s cutoffs). That works
/// only as well as the buckets match a user's actual device, and new
/// devices ship in screen sizes nobody wrote a bucket for; a 14" and 16"
/// laptop, or a small and large phone, could land in the very same bucket
/// and get an identical layout even though the two have meaningfully
/// different room to work with.
///
/// [AppScale.lerp] replaces "which bucket am I in" with "how far between a
/// known small size and a known large size am I, right now" — every
/// widget's numeric sizing (icon size, padding, rail width, font scale)
/// becomes a formula over the real, measured constraint width, evaluated
/// fresh at every width rather than snapped to the nearest preset. The
/// result is a value that's unique to the exact width in view: a window 40
/// logical pixels wider than another one renders very slightly larger
/// controls, not identically-sized ones. `breakpoints.dart`'s named cutoffs
/// still exist for the handful of genuinely binary layout switches (bottom
/// nav vs. sidebar, single-column vs. two-column list) where there's no
/// meaningful "in-between" layout to interpolate toward — but everything
/// that's just a *size*, this file drives instead.
class AppScale {
  const AppScale._();

  /// The width below which sizing bottoms out at [min] — roughly the
  /// smallest phone in real use (iPhone SE-class, ~360dp) — and the width
  /// at or above which it tops out at [max] — a spacious desktop window
  /// (~1600dp, comfortably past a 16" laptop's ~1728dp/1.25 logical-pixel
  /// window in practice, since browser/OS chrome usually leaves less than
  /// the full physical width to the app). Every [lerp] call is anchored to
  /// this same pair of reference widths so a given fraction of the way
  /// between them means the same thing everywhere it's used.
  static const double _minWidth = 360;
  static const double _maxWidth = 1600;

  /// Linearly interpolates between [min] (at [_minWidth] or narrower) and
  /// [max] (at [_maxWidth] or wider) for the given [width], clamped at both
  /// ends so a call never produces a value outside `[min, max]` even for an
  /// extreme width. This is the one formula every continuously-scaled size
  /// in the shared shell goes through — a single, shared curve rather than
  /// each widget inventing its own scaling math, so proportions stay
  /// consistent across the whole shell (the sidebar, header icon, and
  /// header title all reach their "large" size at the same width).
  static double lerp(double width, double min, double max) {
    if (width <= _minWidth) return min;
    if (width >= _maxWidth) return max;
    final t = (width - _minWidth) / (_maxWidth - _minWidth);
    return min + (max - min) * t;
  }
}
