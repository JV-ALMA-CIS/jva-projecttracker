import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';

/// A single at-a-glance metric card for the Executive Dashboard (and any
/// future analytics workspace). Each card carries its own [accentColor] so
/// a row of KPIs reads as distinct sections rather than one flat gray wall
/// — e.g. green for win rate, red/orange for risk, teal for revenue. Follows
/// this project's "reusable component before a new one" rule: intended to
/// be the one KPI-card shape reused across Phase 5's milestones (5.2-5.5),
/// not re-implemented per screen.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.caption,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  /// Optional secondary line, e.g. "12 of 18 decided".
  final String? caption;

  /// Optional trend chip text, e.g. "+8% vs last month". Purely
  /// informational — no direction arrow is inferred from the string.
  final String? trend;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accentColor, width: 4)),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.input),
                      ),
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Chip(
                    label: Text(trend!),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: accentColor),
                    side: BorderSide.none,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
