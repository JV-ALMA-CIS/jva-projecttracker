import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';

/// Lays out [children] as a single stacked column below [breakpoint] (the
/// existing phone behavior), and as an evenly-spaced row of [Expanded]
/// fields once there's enough width — used for the densest field clusters
/// in the Project/Application forms.
class AdaptiveFieldRow extends StatelessWidget {
  const AdaptiveFieldRow({
    super.key,
    required this.children,
    this.breakpoint = AppBreakpoints.compact,
  });

  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint || children.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                child,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: child),
            ],
          ],
        );
      },
    );
  }
}
