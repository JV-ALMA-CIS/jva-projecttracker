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
  });

  final IconData icon;
  final String title;
  final int count;
  final String recentlyUpdatedLabel;
  final String relatedOpportunitiesLabel;
  final KnowledgeHealth health;
  final String healthLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const Spacer(),
                    Text('$count', style: theme.textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  recentlyUpdatedLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  relatedOpportunitiesLabel,
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
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
