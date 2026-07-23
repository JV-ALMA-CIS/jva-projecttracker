import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsStreamProvider);
    final applications = ref.watch(applicationsStreamProvider);
    final contracts = ref.watch(contractsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          projects.when(
            data: (list) {
              final running = list
                  .where((p) => p.status == ProjectStatus.running)
                  .length;
              final planned = list
                  .where((p) => p.status == ProjectStatus.planned)
                  .length;
              final past = list
                  .where((p) => p.status == ProjectStatus.past)
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Running', value: '$running'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Planned', value: '$planned'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Past', value: '$past'),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading projects: $e'),
          ),
          const SizedBox(height: 12),
          applications.when(
            data: (list) =>
                _StatCard(label: 'Applications built', value: '${list.length}'),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading applications: $e'),
          ),
          const SizedBox(height: 24),
          Text(
            'Top contract matches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          contracts.when(
            data: (list) {
              final top = list.take(5).toList();
              if (top.isEmpty) {
                return const Text(
                  'No contracts discovered yet. Run a search from the Contracts tab.',
                );
              }
              return Column(
                children: top
                    .map(
                      (c) => Card(
                        child: ListTile(
                          title: Text(c.title),
                          subtitle: Text(
                            c.client ?? c.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _FitBadge(percent: c.fitScorePercent),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading contracts: $e'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FitBadge extends StatelessWidget {
  const _FitBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final Color color = percent >= 70
        ? Colors.green
        : percent >= 40
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
