import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationsStreamProvider);
    final topContracts = ref.watch(topContractsProvider);
    final running = ref.watch(
      projectStatusCountsProvider.select((c) => c[ProjectStatus.running] ?? 0),
    );
    final planned = ref.watch(
      projectStatusCountsProvider.select((c) => c[ProjectStatus.planned] ?? 0),
    );
    final past = ref.watch(
      projectStatusCountsProvider.select((c) => c[ProjectStatus.past] ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Running',
                  value: '$running',
                  icon: Icons.construction_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Planned',
                  value: '$planned',
                  icon: Icons.event_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Past',
                  value: '$past',
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          applications.when(
            data: (list) => StatCard(
              label: 'Applications built',
              value: '${list.length}',
              icon: Icons.apps_outlined,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading applications: $e'),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Top contract matches'),
          if (topContracts.isEmpty)
            const Text(
              'No contracts discovered yet. Run a search from the Contracts tab.',
            )
          else
            Column(
              children: topContracts
                  .map(
                    (c) => Card(
                      child: ListTile(
                        title: Text(c.title),
                        subtitle: Text(
                          c.client ?? c.sourceUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FitScoreBadge(percent: c.fitScorePercent),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
