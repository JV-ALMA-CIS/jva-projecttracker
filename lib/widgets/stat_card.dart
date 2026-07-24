import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A small stat tile for whole-number counts (project counts, application
/// counts, etc). Never used to render a percentage/progress value — those
/// belong on [FitScoreBadge] only, and only for genuine AI-scored contracts.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Icon(icon, color: Theme.of(context).colorScheme.primary),
            if (icon != null) const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
