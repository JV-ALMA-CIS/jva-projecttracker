import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// A related-entity chip section for Company Intelligence workspace screens
/// (Business Unit/Capability/Product/Service/Technology/Industry/
/// Experience/Knowledge Article) — replaces the `_buildRelatedEntitySection<T>`
/// method every one of those eight screens copy-pasted independently.
///
/// Three things wrong with the original that this fixes:
/// 1. **Dead end.** Chips had no `onTap` at all — seeing "3 related
///    Capabilities" told you nothing you couldn't already see and gave no
///    way to actually get to them. [onTap] now pushes through to that
///    entity's own workspace.
/// 2. **No identity color.** Chips were plain, undifferentiated `Chip`s —
///    now tinted with the same [AppEntityColors] accent used everywhere
///    else that entity type appears (hub tile, list card), so "this chip is
///    a Capability" reads the same way it does anywhere else in the app.
/// 3. **Collapsed by default, unbounded once opened.** The old
///    `ExpansionTile` hid every section behind a tap, then rendered an
///    unbounded `Wrap` of every single related item once opened — fine for
///    3 items, unusable for 50. This widget is expanded by default (it's
///    already inside a scrolling `ListView`, so there's no scroll-budget
///    reason to hide it) and caps the initially-visible count at
///    [collapsedCount], with a "+N more" chip that expands in place rather
///    than opening yet another sheet.
class RelatedEntitySection<T> extends StatefulWidget {
  const RelatedEntitySection({
    super.key,
    required this.title,
    required this.items,
    required this.nameOf,
    required this.accentColor,
    required this.onTap,
    this.collapsedCount = 8,
  });

  final String title;
  final List<T> items;
  final String Function(T item) nameOf;

  /// Entity-type identity color (see `AppEntityColors`) for this
  /// section's chips — e.g. pass `AppEntityColors.capability` when
  /// rendering a business unit's related Capabilities.
  final Color accentColor;

  /// Pushes to the tapped item's own workspace screen — e.g.
  /// `(capability) => pushSlideFade(context, CapabilityWorkspaceScreen(capabilityId: capability.id))`.
  final void Function(T item) onTap;

  final int collapsedCount;

  @override
  State<RelatedEntitySection<T>> createState() =>
      _RelatedEntitySectionState<T>();
}

class _RelatedEntitySectionState<T> extends State<RelatedEntitySection<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final overflow = widget.items.length > widget.collapsedCount;
    final visible = (!_expanded && overflow)
        ? widget.items.take(widget.collapsedCount).toList()
        : widget.items;
    final chipBackground = AppStatusColors.container(widget.accentColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: widget.title,
            accentColor: widget.accentColor,
            trailing: Text(
              '${widget.items.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final item in visible)
                    ActionChip(
                      label: Text(widget.nameOf(item)),
                      backgroundColor: chipBackground,
                      labelStyle: TextStyle(color: widget.accentColor),
                      onPressed: () => widget.onTap(item),
                    ),
                  if (overflow)
                    ActionChip(
                      label: Text(
                        _expanded
                            ? 'Show less'
                            : '+${widget.items.length - widget.collapsedCount} more',
                      ),
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}