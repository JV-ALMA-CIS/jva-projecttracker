import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industry_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industry_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(IndustryStatus status) => switch (status) {
  IndustryStatus.active => AppStatusColors.success,
  IndustryStatus.archived => Colors.grey,
};

class IndustriesScreen extends ConsumerStatefulWidget {
  const IndustriesScreen({super.key});

  @override
  ConsumerState<IndustriesScreen> createState() => _IndustriesScreenState();
}

class _IndustriesScreenState extends ConsumerState<IndustriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  IndustryStatus? _statusFilter;
  String? _sectorFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Industry> _applyFilters(List<Industry> industries) {
    final query = _query.trim().toLowerCase();
    return industries.where((i) {
      if (_statusFilter != null && i.status != _statusFilter) return false;
      if (_sectorFilter != null && i.sector != _sectorFilter) return false;
      if (query.isEmpty) return true;
      return i.name.toLowerCase().contains(query) ||
          i.description.toLowerCase().contains(query) ||
          i.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final industriesAsync = ref.watch(industriesStreamProvider);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(context, const IndustryFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: industriesAsync.when(
          data: (industries) {
            if (industries.isEmpty) {
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
                      icon: Icons.factory_outlined,
                      title: strings.industriesTitle,
                      subtitle: strings.industriesSubtitle,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.factory_outlined,
                      title: strings.noIndustriesYet,
                      action: FilledButton.icon(
                        onPressed: () =>
                            pushSlideFade(context, const IndustryFormScreen()),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newIndustryTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final sectors = {
              for (final i in industries)
                if (i.sector != null && i.sector!.isNotEmpty) i.sector!,
            }.toList()..sort();
            final filtered = _applyFilters(industries);

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
                    icon: Icons.factory_outlined,
                    title: strings.industriesTitle,
                    subtitle: strings.industriesSubtitle,
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
                    hintText: strings.searchIndustriesHint,
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
                      for (final s in IndustryStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                      for (final sector in sectors)
                        FilterChip(
                          label: Text(sector),
                          selected: _sectorFilter == sector,
                          onSelected: (selected) => setState(
                            () => _sectorFilter = selected ? sector : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noIndustriesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, i) => EntityCard(
                            title: i.name,
                            subtitle: i.description,
                            statusBadge: StatusBadge(
                              label: i.status.label,
                              color: _statusColor(i.status),
                            ),
                            metaChips: [
                              if (i.sector != null && i.sector!.isNotEmpty)
                                Chip(
                                  label: Text(i.sector!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ...i.tags.map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              IndustryWorkspaceScreen(industryId: i.id),
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
