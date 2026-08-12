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
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ServiceStatus status) => switch (status) {
  ServiceStatus.active => AppStatusColors.success,
  ServiceStatus.archived => Colors.grey,
};

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key, this.businessUnitId, this.businessUnitName});

  final String? businessUnitId;
  final String? businessUnitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final servicesAsync = businessUnitId == null
        ? ref.watch(servicesStreamProvider)
        : ref.watch(servicesByBusinessUnitProvider(businessUnitId!));
    final title = businessUnitName != null
        ? '$businessUnitName · ${strings.servicesTitle}'
        : strings.servicesTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(context, const ServiceFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: servicesAsync.when(
          data: (services) {
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
                    icon: Icons.design_services_outlined,
                    title: title,
                    subtitle: strings.servicesSubtitle,
                  ),
                ),
                Expanded(
                  child: services.isEmpty
                      ? EmptyState(
                          icon: Icons.design_services_outlined,
                          title: strings.noServicesYet,
                          action: FilledButton.icon(
                            onPressed: () => pushSlideFade(
                              context,
                              const ServiceFormScreen(),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(strings.newServiceTitle),
                          ),
                        )
                      : AdaptiveListGrid(
                          items: services,
                          itemBuilder: (context, service) => EntityCard(
                            title: service.name,
                            subtitle: service.summary.isNotEmpty
                                ? service.summary
                                : service.description,
                            statusBadge: StatusBadge(
                              label: service.status.label,
                              color: _statusColor(service.status),
                            ),
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
