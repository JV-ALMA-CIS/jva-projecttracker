import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/screens/applications/application_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';

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
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                leading: const Icon(Icons.apps_outlined),
                title: Text(a.name),
                subtitle: Text(
                  a.platforms.isEmpty
                      ? a.status.label
                      : '${a.platforms.join(', ')} · ${a.status.label}',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ApplicationFormScreen(application: a),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
