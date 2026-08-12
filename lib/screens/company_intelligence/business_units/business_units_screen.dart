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
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(BusinessUnitStatus status) => switch (status) {
  BusinessUnitStatus.active => AppStatusColors.success,
  BusinessUnitStatus.archived => Colors.grey,
};

/// Was a bare `ConsumerWidget` with no `Scaffold`/`AppBar` of its own even
/// though it's pushed as a standalone route from the Company Intelligence
/// hub (`pushSlideFade(context, category.page)`) — unlike every sibling
/// screen (Products/Services/Capabilities), which already has its own
/// Scaffold+AppBar. That also meant there was nowhere to put a "new
/// Business Unit" action; fixed by giving it the same shape as its
/// siblings.
class BusinessUnitsScreen extends ConsumerWidget {
  const BusinessUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final businessUnits = ref.watch(businessUnitsStreamProvider);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(context, const BusinessUnitFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: businessUnits.when(
          data: (units) {
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
                    icon: Icons.hub_outlined,
                    title: strings.businessUnitsTitle,
                    subtitle: strings.businessUnitsSubtitle,
                  ),
                ),
                Expanded(
                  child: units.isEmpty
                      ? EmptyState(
                          icon: Icons.hub_outlined,
                          title: strings.noBusinessUnitsYet,
                          action: FilledButton.icon(
                            onPressed: () => pushSlideFade(
                              context,
                              const BusinessUnitFormScreen(),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(strings.newBusinessUnitTitle),
                          ),
                        )
                      : AdaptiveListGrid(
                          items: units,
                          itemBuilder: (context, unit) => EntityCard(
                            title: unit.name,
                            subtitle: unit.summary.isNotEmpty
                                ? unit.summary
                                : unit.description,
                            statusBadge: StatusBadge(
                              label: unit.status.label,
                              color: _statusColor(unit.status),
                            ),
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
