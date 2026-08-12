import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/screens/applications/application_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ApplicationStatus status) => switch (status) {
  ApplicationStatus.active => Colors.green,
  ApplicationStatus.maintenance => Colors.orange,
  ApplicationStatus.deprecated => Colors.grey,
};

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final applications = ref.watch(applicationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.applicationsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(context, const ApplicationFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: applications.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(strings.noApplicationsYet));
          }
          return AdaptiveListGrid(
            items: list,
            itemBuilder: (context, a) => EntityCard(
              title: a.name,
              subtitle: a.platforms.isEmpty ? null : a.platforms.join(', '),
              statusBadge: StatusBadge(
                label: strings.applicationStatusLabel(a.status),
                color: _statusColor(a.status),
              ),
              metaChips: a.techStack.map((t) => Chip(label: Text(t))).toList(),
              onTap: () => pushSlideFade(
                context,
                ApplicationFormScreen(applicationId: a.id),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
      ),
    );
  }
}
