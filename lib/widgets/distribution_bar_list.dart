import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// One row of a [DistributionBarList].
class DistributionEntry {
  final String label;
  final int count;
  final Color color;

  const DistributionEntry({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// A dependency-free horizontal bar breakdown — e.g. "opportunities by
/// stage/business unit/industry" on the Executive Dashboard. Deliberately
/// hand-rolled with basic widgets rather than a charting package: this
/// project has no charting dependency yet (see Architectural
/// Recommendations for Milestone 5.1), and a simple proportional bar reads
/// just as clearly for a ranked breakdown of this size. Each row keeps its
/// own [DistributionEntry.color] so a mixed breakdown (e.g. by risk level)
/// stays visually distinct, not just a single-hue bar chart.
class DistributionBarList extends StatelessWidget {
  const DistributionBarList({
    super.key,
    required this.entries,
    this.emptyLabel,
  });

  final List<DistributionEntry> entries;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Text(
        emptyLabel ?? '—',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final maxCount = entries
        .map((e) => e.count)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fraction = entry.count / maxCount;
                        return Stack(
                          children: [
                            Container(
                              height: 18,
                              color: entry.color.withValues(alpha: 0.12),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 18,
                              width:
                                  constraints.maxWidth *
                                  fraction.clamp(0.03, 1.0),
                              color: entry.color,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entry.count}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
