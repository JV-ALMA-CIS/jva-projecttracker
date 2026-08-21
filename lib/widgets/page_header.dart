import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// The platform's one page-title pattern: title + optional subtitle/icon/
/// primary action, used consistently across every top-level and workspace
/// screen instead of each screen picking its own [AppBar] title styling ad
/// hoc. Deliberately built on the existing [TextTheme] scale (headlineSmall
/// for the title, bodyMedium/onSurfaceVariant for the subtitle) rather than
/// introducing a second, parallel typography naming system — the hierarchy
/// comes from consistent *use* of the one scale that already exists, not
/// from new style names.
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.xs),
        ],
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: accentColor != null ? color : null,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: AppSpacing.md), action!],
      ],
    );
  }
}
