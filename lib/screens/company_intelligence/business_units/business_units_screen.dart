import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_unit_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_unit_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(BusinessUnitStatus status) => switch (status) {
  BusinessUnitStatus.active => AppStatusColors.success,
  BusinessUnitStatus.archived => AppStatusColors.neutral,
};

/// Search/filter parity fix on top of the `heroTag: null` fix — see that
/// change's commit message for why every CI FAB now sets it. This screen
/// was a bare `ConsumerWidget` with no search/filter at all — unlike its
/// siblings (Experiences/Industries/Knowledge Base/Technologies), which
/// already had a `SearchBar` + status `FilterChip` row. Same entity shape
/// (a status enum, a handful of text fields), no reason the capability
/// should differ.
class BusinessUnitsScreen extends ConsumerStatefulWidget {
  const BusinessUnitsScreen({super.key});

  @override
  ConsumerState<BusinessUnitsScreen> createState() =>
      _BusinessUnitsScreenState();
}

class _BusinessUnitsScreenState extends ConsumerState<BusinessUnitsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  BusinessUnitStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessUnit> _applyFilters(List<BusinessUnit> units) {
    final query = _query.trim().toLowerCase();
    return units.where((u) {
      if (_statusFilter != null && u.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return u.name.toLowerCase().contains(query) ||
          u.summary.toLowerCase().contains(query) ||
          u.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final businessUnitsAsync = ref.watch(businessUnitsStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // heroTag: null avoids a hero-tag collision with other screens'
        // FABs when two Scaffolds are briefly mounted together (e.g.
        // HomeShell's tab-switch AnimatedSwitcher).
        heroTag: null,
        onPressed: () => pushSlideFade(context, const BusinessUnitFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: businessUnitsAsync.when(
          data: (units) {
            if (units.isEmpty) {
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
                      icon: Icons.apartment_outlined,
                      title: strings.businessUnitsTitle,
                      subtitle: strings.businessUnitsSubtitle,
                      accentColor: AppEntityColors.businessUnit,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.apartment_outlined,
                      title: strings.noBusinessUnitsYet,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          const BusinessUnitFormScreen(),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newBusinessUnitTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final filtered = _applyFilters(units);

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
                    icon: Icons.apartment_outlined,
                    title: strings.businessUnitsTitle,
                    subtitle: strings.businessUnitsSubtitle,
                    accentColor: AppEntityColors.businessUnit,
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
                    hintText: strings.searchBusinessUnitsHint,
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
                      for (final s in BusinessUnitStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noBusinessUnitsMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, unit) => EntityCard(
                            title: unit.name,
                            subtitle: unit.summary.isNotEmpty
                                ? unit.summary
                                : unit.description,
                            statusBadge: StatusBadge(
                              label: unit.status.label,
                              color: _statusColor(unit.status),
                            ),
                            accentColor: AppEntityColors.businessUnit,
                            metaChips: [
                              if (unit.productIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${unit.productIds.length} products',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (unit.serviceIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${unit.serviceIds.length} services',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              BusinessUnitWorkspaceScreen(
                                businessUnitId: unit.id,
                              ),
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
