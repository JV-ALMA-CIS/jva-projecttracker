import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A togglable-chip picker for an entity's relationship fields (e.g.
/// Technology's `businessUnitIds`, Industry's `technologyIds`). Generic over
/// the referenced entity type so the same widget backs every relationship
/// section across the Company Intelligence forms — each caller just supplies
/// its own live stream and id/name accessors.
class RelationshipPicker<T> extends StatelessWidget {
  const RelationshipPicker({
    super.key,
    required this.label,
    required this.optionsAsync,
    required this.idOf,
    required this.nameOf,
    required this.selectedIds,
    required this.onToggle,
  });

  final String label;
  final AsyncValue<List<T>> optionsAsync;
  final String Function(T) idOf;
  final String Function(T) nameOf;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        optionsAsync.when(
          data: (options) {
            if (options.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final o in options)
                  FilterChip(
                    label: Text(nameOf(o)),
                    selected: selectedIds.contains(idOf(o)),
                    onSelected: (selected) => onToggle(idOf(o), selected),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
