import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Renders [items] as a single-column list on narrow screens, and a grid
/// once there's enough width for more than one tile. This is the single
/// place width-based list/grid switching lives — callers just supply an
/// item builder.
class AdaptiveListGrid<T> extends StatelessWidget {
  const AdaptiveListGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.minTileWidth = 320,
    this.tileHeight = 148,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double minTileWidth;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(1, 4);

        if (crossAxisCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => itemBuilder(context, items[i]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: minTileWidth,
            mainAxisExtent: tileHeight,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (context, i) => itemBuilder(context, items[i]),
        );
      },
    );
  }
}
