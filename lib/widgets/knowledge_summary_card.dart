import 'package:flutter/material.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/knowledge_health_style.dart';

/// One entity type's tile on the Company Intelligence Knowledge Workspace
/// landing screen — replaces the plain count-only `StatCard` tile that used
/// to sit there (`StatCard` itself is unchanged and still used everywhere
/// else). Shows the four signals the redesign asks for: total count,
/// recently updated, related opportunities, and an AI health indicator.
class KnowledgeSummaryCard extends StatelessWidget {
  const KnowledgeSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.recentlyUpdatedLabel,
    required this.relatedOpportunitiesLabel,
    required this.health,
    required this.healthLabel,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final int count;
  final String recentlyUpdatedLabel;
  final String relatedOpportunitiesLabel;
  final KnowledgeHealth health;
  final String healthLabel;
  final VoidCallback onTap;

  /// Entity-type identity color (see `AppEntityColors`) for the icon —
  /// distinct from [health]'s background/foreground pair below, which still
  /// carries this entity type's coverage status, not its identity. Falls
  /// back to `colorScheme.primary` when omitted so any other caller keeps
  /// its prior look.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = accentColor ?? theme.colorScheme.primary;
    final (background, foreground) = knowledgeHealthColors(
      theme.colorScheme,
      health,
    );

    return HoverLift(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: iconColor),
                    Text('$count', style: theme.textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  recentlyUpdatedLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  relatedOpportunitiesLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(healthLabel),
                    backgroundColor: background,
                    labelStyle: TextStyle(color: foreground),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}