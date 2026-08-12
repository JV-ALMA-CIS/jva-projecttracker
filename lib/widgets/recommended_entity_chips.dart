import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Renders [ids] as a row of chips showing each entity's resolved name
/// (via [optionsAsync] + [idOf]/[nameOf]), falling back to the raw ID if an
/// entity was deleted after the recommendation was generated. Read-only —
/// used by [OpportunityMatchAnalysisScreen] to display AI-recommended
/// knowledge-graph entries, as opposed to [RelationshipPicker] (which is
/// for editable selection).
class RecommendedEntityChips<T> extends StatelessWidget {
  const RecommendedEntityChips({
    super.key,
    required this.label,
    required this.ids,
    required this.optionsAsync,
    required this.idOf,
    required this.nameOf,
  });

  final String label;
  final List<String> ids;
  final AsyncValue<List<T>> optionsAsync;
  final String Function(T) idOf;
  final String Function(T) nameOf;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          optionsAsync.when(
            data: (options) {
              final byId = {for (final o in options) idOf(o): nameOf(o)};
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final id in ids) Chip(label: Text(byId[id] ?? id)),
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
      ),
    );
  }
}
