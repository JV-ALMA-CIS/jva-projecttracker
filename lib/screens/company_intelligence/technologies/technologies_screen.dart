import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technology_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technology_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

// Was `TechnologyStatus.active => AppStatusColors.technology` — every
// other entity type's `_statusColor` maps active/archived to
// success/neutral; Technology alone used the brand-identity cyan for its
// *status* badge, which meant an active Technology's badge and its
// identity accent were the same color and a coverage/status distinction
// (active vs archived) was invisible. Brought in line with every sibling.
Color _statusColor(TechnologyStatus status) => switch (status) {
  TechnologyStatus.active => AppStatusColors.success,
  TechnologyStatus.archived => AppStatusColors.neutral,
};

class TechnologiesScreen extends ConsumerStatefulWidget {
  const TechnologiesScreen({super.key});

  @override
  ConsumerState<TechnologiesScreen> createState() => _TechnologiesScreenState();
}

class _TechnologiesScreenState extends ConsumerState<TechnologiesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TechnologyStatus? _statusFilter;
  String? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Technology> _applyFilters(List<Technology> technologies) {
    final query = _query.trim().toLowerCase();
    return technologies.where((t) {
      if (_statusFilter != null && t.status != _statusFilter) return false;
      if (_categoryFilter != null && t.category != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return t.name.toLowerCase().contains(query) ||
          t.summary.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query) ||
          t.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          t.keywords.any((k) => k.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final technologiesAsync = ref.watch(technologiesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // heroTag: null avoids a hero-tag collision with other screens'
        // FABs when two Scaffolds are briefly mounted together (e.g.
        // HomeShell's tab-switch AnimatedSwitcher).
        heroTag: null,
        onPressed: () => pushSlideFade(context, const TechnologyFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: technologiesAsync.when(
          data: (technologies) {
            if (technologies.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      leading: PageBackButton(),
                      icon: Icons.memory_outlined,
                      title: strings.technologiesTitle,
                      subtitle: strings.technologiesSubtitle,
                      accentColor: AppEntityColors.technology,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.memory_outlined,
                      title: strings.noTechnologiesYet,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          const TechnologyFormScreen(),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newTechnologyTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final categories = {
              for (final t in technologies)
                if (t.category != null && t.category!.isNotEmpty) t.category!,
            }.toList()..sort();
            final filtered = _applyFilters(technologies);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: PageHeader(
                    leading: PageBackButton(),
                    icon: Icons.memory_outlined,
                    title: strings.technologiesTitle,
                    subtitle: strings.technologiesSubtitle,
                    accentColor: AppEntityColors.technology,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: strings.searchTechnologiesHint,
                    leading: const Icon(Icons.search),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilterChip(
                        label: Text(strings.filterAllLabel),
                        selected: _statusFilter == null,
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      for (final s in TechnologyStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                      for (final c in categories)
                        FilterChip(
                          label: Text(c),
                          selected: _categoryFilter == c,
                          onSelected: (selected) => setState(
                            () => _categoryFilter = selected ? c : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noTechnologiesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, t) => EntityCard(
                            title: t.name,
                            subtitle: t.summary.isNotEmpty
                                ? t.summary
                                : t.description,
                            statusBadge: StatusBadge(
                              label: t.status.label,
                              color: _statusColor(t.status),
                            ),
                            accentColor: AppEntityColors.technology,
                            metaChips: [
                              if (t.category != null && t.category!.isNotEmpty)
                                Chip(
                                  label: Text(t.category!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ...t.tags.map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              TechnologyWorkspaceScreen(technologyId: t.id),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(strings.errorPrefix(error))),
        ),
      ),
    );
  }
}
