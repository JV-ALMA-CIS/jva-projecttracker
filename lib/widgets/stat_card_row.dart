import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';

/// Lays out a workspace's KPI [StatCard]s as a single evenly-spaced row
/// above [AppBreakpoints.compact], and as a 2-column wrap below it — the
/// shared fix for the "KPI row squished/overflowing on a narrow phone"
/// issue that recurs across every Company Intelligence workspace (Business
/// Unit/Product/Capability/Experience/…). Each card is still given equal
/// width via [Expanded] in row mode; in wrap mode each card takes half the
/// available width minus the inter-card gap.
class StatCardRow extends StatelessWidget {
  const StatCardRow({
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
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: child),
              ],
            ],
          );
        }

        final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
