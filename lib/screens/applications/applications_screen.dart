import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/screens/applications/application_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
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
    final applications = ref.watch(applicationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ApplicationFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: applications.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No applications catalogued yet. Tap + to add one.'),
            );
          }
          return AdaptiveListGrid(
            items: list,
            itemBuilder: (context, a) => EntityCard(
              title: a.name,
              subtitle: a.platforms.isEmpty ? null : a.platforms.join(', '),
              statusBadge: StatusBadge(
                label: a.status.label,
                color: _statusColor(a.status),
              ),
              metaChips: a.techStack.map((t) => Chip(label: Text(t))).toList(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ApplicationFormScreen(applicationId: a.id),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
