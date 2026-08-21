import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';

/// Generic list/grid item card used by Projects and Applications: a title,
/// optional subtitle, a status badge pinned to the top-right, and a row of
/// meta chips beneath. Kept generic so per-entity cards (e.g. `ProjectCard`)
/// only need to decide what goes in each slot.
///
/// Every caller renders this inside `AdaptiveListGrid`'s grid mode, whose
/// `SliverGridDelegateWithMaxCrossAxisExtent` gives each tile a *fixed*
/// `mainAxisExtent` (`tileHeight`) — there is no way for a grid cell to grow
/// to fit its content. Title/subtitle are already single-line-clamped, but
/// [metaChips] used to be an unbounded `Wrap`: a caller supplying enough
/// chips to wrap past one row (`ProjectCard` can supply up to 5) made the
/// card's real content taller than its fixed cell, producing a genuine
/// `RenderFlex overflowed` — not a cosmetic one-off, but a mismatch between
/// this widget's max possible height and the fixed grid extent every caller
/// renders it inside. [maxChipRows] caps how many `Wrap` rows are shown
/// (default 1) and folds anything past that into a "+N" chip, keeping this
/// widget's height bounded and predictable regardless of how many chips a
/// caller passes, rather than raising `tileHeight` values project-by-project
/// as new chips get added later.
class EntityCard extends StatelessWidget {
  const EntityCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.statusBadge,
    this.metaChips = const [],
    this.onTap,
    this.maxVisibleChips = 3,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final Widget statusBadge;
  final List<Widget> metaChips;
  final VoidCallback? onTap;

  /// Chips beyond this count collapse into a single "+N" chip instead of
  /// wrapping to further rows, so the card's height stays bounded no matter
  /// how many meta chips a caller supplies.
  final int maxVisibleChips;

  /// Optional category identity color (see `AppEntityColors`), rendered as a
  /// thin left-edge stripe — distinct from [statusBadge], which still
  /// carries this specific record's state. Omit for entity types that don't
  /// participate in the categorical palette; the card renders exactly as
  /// before.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final overflowCount = metaChips.length > maxVisibleChips
        ? metaChips.length - maxVisibleChips
        : 0;
    final visibleChips = overflowCount > 0
        ? metaChips.take(maxVisibleChips).toList()
        : metaChips;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              statusBadge,
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (visibleChips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  for (final chip in visibleChips) ...[
                    Flexible(child: chip),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (overflowCount > 0)
                    Chip(
                      label: Text('+$overflowCount'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    // No CrossAxisAlignment.stretch here — this Row's parent has a fixed
    // height only in AdaptiveListGrid's grid mode (SliverGridDelegate's
    // mainAxisExtent). In its single-column list mode (used at narrow/
    // mobile widths, via ListView.separated) each item gets its natural
    // content height instead — unbounded — and `stretch` on an unbounded
    // Row height throws "BoxConstraints forces an infinite height".
    // IntrinsicHeight measures `content` first and gives the accent stripe
    // that same height, achieving the same visual result without requiring
    // a bounded ancestor.
    final row = accentColor == null
        ? Row(
            children: [
              Expanded(
                child: InkWell(onTap: onTap, child: content),
              ),
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(
                  child: InkWell(onTap: onTap, child: content),
                ),
              ],
            ),
          );

    return HoverLift(
      child: Card(clipBehavior: Clip.antiAlias, child: row),
    );
  }
}
