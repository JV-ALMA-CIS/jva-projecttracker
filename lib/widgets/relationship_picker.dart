import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// A togglable-chip picker for an entity's relationship fields (e.g.
/// Technology's `businessUnitIds`, Industry's `technologyIds`). Generic over
/// the referenced entity type so the same widget backs every relationship
/// section across the Company Intelligence forms — each caller just supplies
/// its own live stream and id/name accessors.
///
/// Redesigned: previously rendered *every* available option as an inline
/// `FilterChip` in an unbounded `Wrap`. Fine for a handful of options, but
/// this section's height grew with the size of the underlying collection,
/// not with how many were actually selected — `KnowledgeFormScreen` stacks
/// seven of these, so a Capabilities collection with 50 entries turned one
/// relationship section into a 50-chip wall whether 0 or 40 were selected,
/// and multiplied by seven sections that's an unusable scroll. Now this
/// widget only ever renders what's *selected* (as removable `InputChip`s)
/// plus one "Add"/"Edit" affordance; the full searchable option list lives
/// in a bottom sheet opened on demand. A form's scroll length now depends
/// on what the user picked, not on how large the collection has grown to.
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

  Future<void> _openPicker(BuildContext context, List<T> options) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RelationshipPickerSheet<T>(
        label: label,
        options: options,
        idOf: idOf,
        nameOf: nameOf,
        selectedIds: selectedIds,
        onToggle: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return optionsAsync.when(
      data: (options) {
        final selected = options
            .where((o) => selectedIds.contains(idOf(o)))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.labelLarge),
                ),
                if (options.isNotEmpty)
                  Text(
                    '${selected.length}/${options.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final o in selected)
                  InputChip(
                    label: Text(nameOf(o)),
                    onDeleted: () => onToggle(idOf(o), false),
                  ),
                ActionChip(
                  avatar: Icon(
                    Icons.add,
                    size: 18,
                    color: options.isEmpty
                        ? theme.disabledColor
                        : theme.colorScheme.primary,
                  ),
                  label: Text(selected.isEmpty ? 'Add' : 'Edit'),
                  onPressed: options.isEmpty
                      ? null
                      : () => _openPicker(context, options),
                ),
              ],
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
    );
  }
}

/// The searchable option list opened by [RelationshipPicker._openPicker].
/// Keeps its own local copy of the selection for immediate checkbox
/// feedback inside the sheet — the sheet is a separate overlay route, so it
/// won't automatically repaint in response to the parent form's `setState`
/// the way an inline widget would. [onToggle] is still called on every
/// change so the parent form's real state (and therefore the chip row
/// behind the sheet) stays in sync once the sheet closes.
class _RelationshipPickerSheet<T> extends StatefulWidget {
  const _RelationshipPickerSheet({
    required this.label,
    required this.options,
    required this.idOf,
    required this.nameOf,
    required this.selectedIds,
    required this.onToggle,
  });

  final String label;
  final List<T> options;
  final String Function(T) idOf;
  final String Function(T) nameOf;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  State<_RelationshipPickerSheet<T>> createState() =>
      _RelationshipPickerSheetState<T>();
}

class _RelationshipPickerSheetState<T>
    extends State<_RelationshipPickerSheet<T>> {
  late final Set<String> _localSelected = {...widget.selectedIds};
  String _query = '';

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        _localSelected.add(id);
      } else {
        _localSelected.remove(id);
      }
    });
    widget.onToggle(id, selected);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options
              .where((o) => widget.nameOf(o).toLowerCase().contains(query))
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matches'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final o = filtered[i];
                        final id = widget.idOf(o);
                        return CheckboxListTile(
                          value: _localSelected.contains(id),
                          title: Text(widget.nameOf(o)),
                          onChanged: (checked) =>
                              _toggle(id, checked ?? false),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}