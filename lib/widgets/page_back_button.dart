import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';

/// The platform's one "go back" control for screens that dropped their
/// [AppBar] in favor of putting everything in a [PageHeader] row instead —
/// meant for [PageHeader.leading]. A tinted, outlined chip (not a bare
/// [IconButton]) so it reads as a deliberate, tappable control rather than
/// empty space where a toolbar used to be — a plain low-alpha `onSurface`
/// fill read as near-invisible in practice, so this uses
/// [ColorScheme.primary] at a stronger tint plus a [ColorScheme.outlineVariant]
/// border for real contrast against the page background in both themes.
///
/// Calls [Navigator.maybePop] rather than [Navigator.pop] — safe to use on
/// a screen that might occasionally be the root of its stack (e.g. reached
/// via a deep link) without needing every caller to check first.
class PageBackButton extends ConsumerWidget {
  const PageBackButton({super.key, this.label, this.hideOnCompact = false});

  /// Text shown next to the arrow. Omit to fall back to
  /// [AppStrings.backButton], shown automatically on screens at or above
  /// [AppBreakpoints.compact] (600) and suppressed below it — a narrow
  /// header is exactly where a text label would crowd the rest of
  /// [PageHeader]'s row. Pass `''` explicitly for an icon-only button even
  /// on wide screens, or a non-empty string to force the label on at any
  /// width.
  final String? label;

  /// When true, this renders as nothing on screens narrower than
  /// [AppBreakpoints.compact] (600) — on the assumption that the platform's
  /// own back gesture/button is enough there and a second on-screen control
  /// is redundant. Defaults to false — every current caller wants the
  /// button always visible, since Flutter Web has no reliable system back
  /// gesture to fall back on.
  final bool hideOnCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    if (hideOnCompact && isCompact) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final button = InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 20, color: scheme.primary),
      ),
    );

    // Default label only shows when there's real room for it — a narrow
    // header is exactly where a text label would crowd the rest of
    // PageHeader's row (icon, title, trailing action), regardless of
    // whether this instance is also using hideOnCompact to hide entirely.
    final resolvedLabel =
        label ?? (isCompact ? '' : ref.watch(appStringsProvider).backButton);
    if (resolvedLabel.isEmpty) return button;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: AppSpacing.sm),
        Text(resolvedLabel, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
