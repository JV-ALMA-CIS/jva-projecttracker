import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProjectFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: projects.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No projects yet. Tap + to add one.'),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                leading: CircleAvatar(child: Text(p.status.label[0])),
                title: Text(p.name),
                subtitle: Text('${p.client} · ${p.status.label}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectFormScreen(project: p),
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
