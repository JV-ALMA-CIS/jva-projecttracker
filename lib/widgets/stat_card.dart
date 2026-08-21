import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';

/// A small stat tile for whole-number counts (project counts, application
/// counts, Company Intelligence entity counts, etc). Never used to render a
/// percentage/progress value — those belong on [FitScoreBadge] only, and only
/// for genuine AI-scored opportunities.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, color: Theme.of(context).colorScheme.primary),
          if (icon != null) const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final card = Card(
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: onTap,
              child: content,
            ),
    );

    return onTap == null ? card : HoverLift(child: card);
  }
}
