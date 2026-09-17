import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_scale.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// The platform's one page-title pattern: title + optional subtitle/icon/
/// primary action, used consistently across every top-level and workspace
/// screen instead of each screen picking its own [AppBar] title styling ad
/// hoc. Deliberately built on the existing [TextTheme] scale (headlineSmall
/// for the title, bodyMedium/onSurfaceVariant for the subtitle) rather than
/// introducing a second, parallel typography naming system — the hierarchy
/// comes from consistent *use* of the one scale that already exists, not
/// from new style names.
///
/// Scales itself continuously against the row's own available width (via
/// [LayoutBuilder] + [AppScale.lerp], not the full window width — this also
/// does the right thing inside a narrower split-view pane) rather than
/// switching between a couple of fixed looks: the icon chip size/padding,
/// the title's font size, and the inter-element gaps are all formulas over
/// the exact measured width, so a 400dp-wide header and a 420dp-wide one
/// render very slightly differently instead of both being forced into the
/// same "small" or "large" preset. This is what keeps the header from
/// crowding on a small phone without needing a name for every phone size
/// that exists today or ships tomorrow.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.action,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Rendered before the icon/title — e.g. a back [IconButton] for a screen
  /// that dropped its [AppBar] in favor of putting everything (back button,
  /// icon, title, actions) in this one header row instead of a separate
  /// 56dp toolbar above it.
  final Widget? leading;
  final Widget? action;

  /// Per-page semantic accent (see [AppStatusColors]) for the icon chip and
  /// title text — e.g. Opportunities reads as blue, Company Intelligence
  /// entity pages read as their own category color, Submissions as info.
  /// Defaults to `colorScheme.primary` (brand navy) when omitted, so every
  /// existing caller keeps its prior look unless it opts in.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final iconSize = AppScale.lerp(width, 18, 24);
        final iconPadding = AppScale.lerp(width, AppSpacing.xs, AppSpacing.sm);
        final iconGap = AppScale.lerp(width, AppSpacing.sm, AppSpacing.md);
        final actionGap = AppScale.lerp(width, AppSpacing.sm, AppSpacing.md);

        // headlineSmall's own fontSize is the "large" end of the curve;
        // 20 is roughly titleLarge's size, the "small" end — interpolating
        // the raw number (rather than switching between the two named
        // TextTheme styles) is what makes the title's size continuous
        // instead of a single jump at one width.
        final baseTitleStyle = theme.textTheme.headlineSmall;
        final titleFontSize = AppScale.lerp(
          width,
          20,
          baseTitleStyle?.fontSize ?? 24,
        );

        // Only a genuinely cramped width needs the title to wrap to a
        // second line at all — above that, one line plus ellipsis reads
        // better than an early wrap.
        final titleMaxLines = width < 340 ? 2 : 1;
        final subtitleMaxLines = width < 340 ? 1 : 2;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.xs),
            ],
            if (icon != null) ...[
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.input),
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              SizedBox(width: iconGap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: baseTitleStyle?.copyWith(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: accentColor != null ? color : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[SizedBox(width: actionGap), action!],
          ],
        );
      },
    );
  }
}
