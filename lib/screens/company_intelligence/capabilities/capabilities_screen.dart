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
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(CapabilityStatus status) => switch (status) {
  CapabilityStatus.active => AppStatusColors.success,
  CapabilityStatus.archived => Colors.grey,
};

class CapabilitiesScreen extends ConsumerWidget {
  const CapabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final capabilitiesAsync = ref.watch(capabilitiesStreamProvider);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(context, const CapabilityFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: capabilitiesAsync.when(
          data: (capabilities) {
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
                    icon: Icons.extension_outlined,
                    title: strings.capabilitiesTitle,
                    subtitle: strings.capabilitiesSubtitle,
                  ),
                ),
                Expanded(
                  child: capabilities.isEmpty
                      ? EmptyState(
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
                        )
                      : AdaptiveListGrid(
                          items: capabilities,
                          itemBuilder: (context, capability) => EntityCard(
                            title: capability.name,
                            subtitle: capability.summary.isNotEmpty
                                ? capability.summary
                                : capability.description,
                            statusBadge: StatusBadge(
                              label: capability.status.label,
                              color: _statusColor(capability.status),
                            ),
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
