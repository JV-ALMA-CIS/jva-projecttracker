import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/discovery_source.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_history_screen.dart';
import 'package:jva_projecttracker/services/discovery_engine_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Automated adapters exist today only for the 5 "searchable" source types
/// (see `functions/index.js`'s `DISCOVERY_ADAPTERS` registry) — `rss`/`api`
/// are real, creatable source types whose "Run now" cleanly reports "not yet
/// automated" rather than doing nothing fake. `manual` has no "Run now" at
/// all; opportunities of that type are added directly below instead.
const _kAutomatedSourceTypes = {
  DiscoverySourceType.governmentProcurement,
  DiscoverySourceType.developmentOrganization,
  DiscoverySourceType.unProcurement,
  DiscoverySourceType.ngo,
  DiscoverySourceType.privateSector,
};

/// Manages [DiscoverySource]s and provides the manual-import entry point.
/// See the Opportunity Discovery Engine (Milestone 3.7).
class DiscoverySourcesScreen extends ConsumerWidget {
  const DiscoverySourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final sources = ref.watch(discoverySourcesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.discoverySourcesTitle),
        actions: [
          IconButton(
            onPressed: () =>
                pushSlideFade(context, const DiscoveryHistoryScreen()),
            icon: const Icon(Icons.history),
            tooltip: strings.discoveryHistoryTooltip,
          ),
          IconButton(
            onPressed: () => _showManualOpportunityDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: strings.addOpportunityManuallyTitle,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: PageHeader(
              icon: Icons.travel_explore_outlined,
              title: strings.discoverySourcesTitle,
              accentColor: AppStatusColors.info,
            ),
          ),
          Expanded(
            child: sources.when(
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.travel_explore_outlined,
                    title: strings.noDiscoverySourcesMessage,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    return FadeSlideIn(
                      index: i,
                      child: _SourceTile(source: list[i]),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // heroTag: null avoids a hero-tag collision with other screens'
        // FABs when two Scaffolds are briefly mounted together (e.g.
        // HomeShell's tab-switch AnimatedSwitcher) — see ProjectsScreen.
        heroTag: null,
        onPressed: () => _showSourceFormDialog(context, ref),
        tooltip: strings.addSourceTitle,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Shows the "add opportunity manually" dialog. Public because the primary
/// entry point for it now lives on the Opportunities hub's Pipeline tab
/// (see `opportunities_screen.dart`) — this screen is retiring from the
/// main Opportunities navigation now that Tender Sources (Milestone 3.8c)
/// supersedes it, but the dialog itself is still the one real piece of
/// functionality worth keeping, so it moved rather than being duplicated.
void showManualOpportunityDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (context) => const _ManualOpportunityDialog(),
  );
}

void _showSourceFormDialog(
  BuildContext context,
  WidgetRef ref, {
  DiscoverySource? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _SourceFormDialog(existing: existing),
  );
}

void _showManualOpportunityDialog(BuildContext context, WidgetRef ref) =>
    showManualOpportunityDialog(context, ref);

class _SourceTile extends ConsumerStatefulWidget {
  const _SourceTile({required this.source});

  final DiscoverySource source;

  @override
  ConsumerState<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends ConsumerState<_SourceTile> {
  bool _running = false;

  Future<void> _runNow() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _running = true);
    try {
      final created = await ref
          .read(discoveryEngineServiceProvider)
          .runSource(widget.source.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.runCreatedOpportunities(created))),
        );
      }
    } on DiscoveryEngineException catch (e) {
      _log.e('Discovery run failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.runFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final source = widget.source;
    final isAutomated = _kAutomatedSourceTypes.contains(source.type);
    final isManual = source.type == DiscoverySourceType.manual;

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: ListTile(
          onTap: () => _showSourceFormDialog(context, ref, existing: source),
          title: Text(source.name),
          subtitle: Text(strings.discoverySourceTypeLabel(source.type)),
          leading: Switch(
            value: source.enabled,
            onChanged: (v) => ref
                .read(discoverySourceServiceProvider)
                .setEnabled(source.id, v),
          ),
          trailing: isManual
              ? null
              : _running
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: isAutomated ? _runNow : null,
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: isAutomated
                      ? strings.runNowButton
                      : strings.notYetAutomatedTooltip,
                ),
        ),
      ),
    );
  }
}

class _SourceFormDialog extends ConsumerStatefulWidget {
  const _SourceFormDialog({this.existing});

  final DiscoverySource? existing;

  @override
  ConsumerState<_SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends ConsumerState<_SourceFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _queryController = TextEditingController(
    text: widget.existing?.searchQuery,
  );
  late DiscoverySourceType _type =
      widget.existing?.type ?? DiscoverySourceType.governmentProcurement;

  @override
  void dispose() {
    _nameController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final service = ref.read(discoverySourceServiceProvider);
    final now = DateTime.now();
    final query = _queryController.text.trim();
    final existing = widget.existing;

    if (existing == null) {
      await service.create(
        DiscoverySource(
          id: '',
          name: name,
          type: _type,
          searchQuery: query.isEmpty ? null : query,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await service.update(
        DiscoverySource(
          id: existing.id,
          name: name,
          type: _type,
          searchQuery: query.isEmpty ? null : query,
          endpointUrl: existing.endpointUrl,
          enabled: existing.enabled,
          lastRunAt: existing.lastRunAt,
          createdAt: existing.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? strings.addSourceTitle
            : strings.editSourceTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: strings.fieldSourceName),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<DiscoverySourceType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: strings.fieldSourceType),
              items: DiscoverySourceType.values
                  .where((t) => t != DiscoverySourceType.manual)
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(strings.discoverySourceTypeLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _queryController,
              decoration: InputDecoration(labelText: strings.fieldSearchQuery),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.saveButton)),
      ],
    );
  }
}

class _ManualOpportunityDialog extends ConsumerStatefulWidget {
  const _ManualOpportunityDialog();

  @override
  ConsumerState<_ManualOpportunityDialog> createState() =>
      _ManualOpportunityDialogState();
}

class _ManualOpportunityDialogState
    extends ConsumerState<_ManualOpportunityDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _procuringOrganizationController = TextEditingController();
  final _tenderReferenceNumberController = TextEditingController();
  final _requiredTechnologiesController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _clientController.dispose();
    _sourceUrlController.dispose();
    _procuringOrganizationController.dispose();
    _tenderReferenceNumberController.dispose();
    _requiredTechnologiesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final client = _clientController.text.trim();
    final sourceUrl = _sourceUrlController.text.trim();
    final procuringOrganization = _procuringOrganizationController.text.trim();
    final tenderReferenceNumber = _tenderReferenceNumberController.text.trim();
    final requiredTechnologies = _requiredTechnologiesController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    await ref
        .read(opportunityServiceProvider)
        .create(
          Opportunity(
            id: '',
            title: title,
            description: _descriptionController.text.trim(),
            sourceUrl: sourceUrl,
            // Human-typed, not an AI-search guess — no fabrication risk to
            // warn about, so this is verified from the moment it's entered.
            sourceUrlVerified: true,
            sourceUrlVerifiedAt: now,
            client: client.isEmpty ? null : client,
            procuringOrganization: procuringOrganization.isEmpty
                ? null
                : procuringOrganization,
            tenderReferenceNumber: tenderReferenceNumber.isEmpty
                ? null
                : tenderReferenceNumber,
            requiredTechnologies: requiredTechnologies,
            discoveredAt: now,
            updatedAt: now,
            discoverySourceType: DiscoverySourceType.manual,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(strings.addOpportunityManuallyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.fieldOpportunityTitle,
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: strings.fieldDescription),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _clientController,
              decoration: InputDecoration(labelText: strings.fieldClient),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _sourceUrlController,
              decoration: InputDecoration(labelText: strings.fieldSourceUrl),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _procuringOrganizationController,
              decoration: InputDecoration(
                labelText: strings.fieldProcuringOrganization,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _tenderReferenceNumberController,
              decoration: InputDecoration(
                labelText: strings.fieldTenderReferenceNumber,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _requiredTechnologiesController,
              decoration: InputDecoration(
                labelText: strings.fieldRequiredTechnologies,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.addButton)),
      ],
    );
  }
}
