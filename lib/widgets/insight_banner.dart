import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A colored-container status banner — icon + message on a tinted
/// background, used wherever a screen needs to call out one overall
/// pass/fail state at a glance (e.g. "ready to submit" vs "blockers
/// remain"). Extracted from what was previously an ad hoc `Container` in
/// the Submission Workspace so any future banner reuses the same shape.
class InsightBanner extends StatelessWidget {
  const InsightBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.isPositive,
  });

  final IconData icon;
  final String message;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isPositive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = isPositive
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
