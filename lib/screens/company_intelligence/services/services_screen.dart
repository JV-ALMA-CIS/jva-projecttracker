import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/service_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/service_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ServiceStatus status) => switch (status) {
  ServiceStatus.active => AppStatusColors.success,
  ServiceStatus.archived => AppStatusColors.neutral,
};

/// Search/filter parity fix on top of the `heroTag: null` fix — see
/// `BusinessUnitsScreen`'s doc comment. [businessUnitId]/[businessUnitName]
/// are unchanged: the FAB still opens a plain `ServiceFormScreen()` with no
/// `businessUnitId` passed through, matching the pre-existing behavior here
/// (this file's original didn't wire that through either, unlike
/// `ProductsScreen`'s FAB — left as-is rather than silently changing
/// creation behavior; worth a follow-up if that was actually a bug).
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.businessUnitId, this.businessUnitName});

  final String? businessUnitId;
  final String? businessUnitName;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ServiceStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceModel> _applyFilters(List<ServiceModel> services) {
    final query = _query.trim().toLowerCase();
    return services.where((s) {
      if (_statusFilter != null && s.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return s.name.toLowerCase().contains(query) ||
          s.summary.toLowerCase().contains(query) ||
          s.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final servicesAsync = widget.businessUnitId == null
        ? ref.watch(servicesStreamProvider)
        : ref.watch(servicesByBusinessUnitProvider(widget.businessUnitId!));
    final title = widget.businessUnitName != null
        ? '${widget.businessUnitName} · ${strings.servicesTitle}'
        : strings.servicesTitle;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => pushSlideFade(context, const ServiceFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
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
                      icon: Icons.design_services_outlined,
                      title: title,
                      subtitle: strings.servicesSubtitle,
                      accentColor: AppEntityColors.service,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.design_services_outlined,
                      title: strings.noServicesYet,
                      action: FilledButton.icon(
                        onPressed: () =>
                            pushSlideFade(context, const ServiceFormScreen()),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newServiceTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final filtered = _applyFilters(services);

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
                    icon: Icons.design_services_outlined,
                    title: title,
                    subtitle: strings.servicesSubtitle,
                    accentColor: AppEntityColors.service,
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
                    hintText: strings.searchServicesHint,
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
                      for (final s in ServiceStatus.values)
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
                          title: strings.noServicesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, service) => EntityCard(
                            title: service.name,
                            subtitle: service.summary.isNotEmpty
                                ? service.summary
                                : service.description,
                            statusBadge: StatusBadge(
                              label: service.status.label,
                              color: _statusColor(service.status),
                            ),
                            accentColor: AppEntityColors.service,
                            metaChips: [
                              if (service.businessUnitIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${service.businessUnitIds.length} business units',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (service.capabilityIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${service.capabilityIds.length} capabilities',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (service.industryIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${service.industryIds.length} industries',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              ServiceWorkspaceScreen(serviceId: service.id),
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
