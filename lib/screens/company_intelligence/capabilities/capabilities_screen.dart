import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capability_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capability_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(CapabilityStatus status) => switch (status) {
  CapabilityStatus.active => AppStatusColors.success,
  CapabilityStatus.archived => AppStatusColors.neutral,
};

/// Search/filter parity fix on top of the `heroTag: null` fix — see
/// `BusinessUnitsScreen`'s doc comment. Filters by status and by tag
/// (Capability already carries a `tags` field, same role `sector` plays on
/// `IndustriesScreen`).
class CapabilitiesScreen extends ConsumerStatefulWidget {
  const CapabilitiesScreen({super.key});

  @override
  ConsumerState<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends ConsumerState<CapabilitiesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CapabilityStatus? _statusFilter;
  String? _tagFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Capability> _applyFilters(List<Capability> capabilities) {
    final query = _query.trim().toLowerCase();
    return capabilities.where((c) {
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (_tagFilter != null && !c.tags.contains(_tagFilter)) return false;
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.summary.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.keywords.any((k) => k.toLowerCase().contains(query)) ||
          c.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final capabilitiesAsync = ref.watch(capabilitiesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => pushSlideFade(context, const CapabilityFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: capabilitiesAsync.when(
          data: (capabilities) {
            if (capabilities.isEmpty) {
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
                      icon: Icons.extension_outlined,
                      title: strings.capabilitiesTitle,
                      subtitle: strings.capabilitiesSubtitle,
                      accentColor: AppEntityColors.capability,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.extension_outlined,
                      title: strings.noCapabilitiesYet,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          const CapabilityFormScreen(),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newCapabilityTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final tags = {for (final c in capabilities) ...c.tags}.toList()
              ..sort();
            final filtered = _applyFilters(capabilities);

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
                    icon: Icons.extension_outlined,
                    title: strings.capabilitiesTitle,
                    subtitle: strings.capabilitiesSubtitle,
                    accentColor: AppEntityColors.capability,
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
                    hintText: strings.searchCapabilitiesHint,
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
                        selected: _statusFilter == null && _tagFilter == null,
                        onSelected: (_) => setState(() {
                          _statusFilter = null;
                          _tagFilter = null;
                        }),
                      ),
                      for (final s in CapabilityStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                      for (final tag in tags)
                        FilterChip(
                          label: Text(tag),
                          selected: _tagFilter == tag,
                          onSelected: (selected) => setState(
                            () => _tagFilter = selected ? tag : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noCapabilitiesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, capability) => EntityCard(
                            title: capability.name,
                            subtitle: capability.summary.isNotEmpty
                                ? capability.summary
                                : capability.description,
                            statusBadge: StatusBadge(
                              label: capability.status.label,
                              color: _statusColor(capability.status),
                            ),
                            accentColor: AppEntityColors.capability,
                            metaChips: [
                              for (final keyword in capability.keywords.take(4))
                                Chip(
                                  label: Text(keyword),
                                  visualDensity: VisualDensity.compact,
                                ),
                              for (final tag in capability.tags.take(4))
                                Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              CapabilityWorkspaceScreen(
                                capabilityId: capability.id,
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
