import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/contract.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger();

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  bool _searching = false;

  Future<void> _runDiscovery() async {
    setState(() => _searching = true);
    try {
      final created = await ref
          .read(contractServiceProvider)
          .triggerDiscoveryRun();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found $created new opportunities')),
        );
      }
    } catch (e) {
      _log.e('Contract discovery failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contracts = ref.watch(contractsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        actions: [
          IconButton(
            onPressed: _searching ? null : _runDiscovery,
            icon: _searching
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_outlined),
            tooltip: 'Search for new contracts',
          ),
        ],
      ),
      body: contracts.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No contracts discovered yet.'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _searching ? null : _runDiscovery,
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: const Text('Search now'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return _ContractTile(contract: c);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ContractTile extends ConsumerWidget {
  const _ContractTile({required this.contract});

  final Contract contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: FitScoreBadge(percent: contract.fitScorePercent, size: 36),
        title: Text(contract.title),
        subtitle: Text(
          contract.client ?? contract.sourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contract.description),
                const SizedBox(height: 8),
                if (contract.fitReasoning.isNotEmpty) ...[
                  Text(
                    'Fit reasoning',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(contract.fitReasoning),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  children: contract.tags
                      .map((t) => Chip(label: Text(t)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(contract.sourceUrl)),
                      child: const Text('Open source'),
                    ),
                    const Spacer(),
                    DropdownButton<ContractStatus>(
                      value: contract.status,
                      items: ContractStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (s) {
                        if (s != null) {
                          ref
                              .read(contractServiceProvider)
                              .updateStatus(contract.id, s);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
