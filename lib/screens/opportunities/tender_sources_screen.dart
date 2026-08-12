import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/services/tender_source_seed_service.dart';
import 'package:jva_projecttracker/services/tender_sync_service.dart';
import 'package:jva_projecttracker/screens/opportunities/tender_source_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:logger/logger.dart';

final _log = Logger();

Color _statusColor(ColorScheme scheme, TenderSourceStatus status) =>
    switch (status) {
      TenderSourceStatus.active => AppStatusColors.success,
      TenderSourceStatus.paused => scheme.outline,
      TenderSourceStatus.offline => AppStatusColors.warning,
      TenderSourceStatus.error => scheme.error,
    };

/// Admin CRUD workspace for [TenderSource]s (Milestone 3.8c). Firestore
/// rules restrict writes here to admins (`isAdmin()` in firestore.rules) —
/// this screen doesn't re-check the role client-side, since a denied write
/// simply surfaces as a normal Firestore permission error, same pattern as
/// every other admin-only collection in this app.
///
/// The "Seed Production Sources" action (app bar + empty-state button)
/// calls `seedProductionTenderSources`, which populates the 30 real
/// government/donor/UN/NGO organizations from the Phase 3 brief — see
/// functions/seedTenderSources.js. Idempotent, so it's safe to tap more
/// than once.
class TenderSourcesScreen extends ConsumerStatefulWidget {
  const TenderSourcesScreen({super.key});

  @override
  ConsumerState<TenderSourcesScreen> createState() =>
      _TenderSourcesScreenState();
}

class _TenderSourcesScreenState extends ConsumerState<TenderSourcesScreen> {
  bool _seeding = false;

  Future<void> _seedProductionSources() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _seeding = true);
    try {
      final result = await ref
          .read(tenderSourceSeedServiceProvider)
          .seedProductionSources();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.seedResultMessage(result.created, result.skipped),
            ),
          ),
        );
      }
    } on TenderSourceSeedException catch (e) {
      _log.e('Seeding production sources failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final sources = ref.watch(tenderSourcesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tenderSourcesTitle),
        actions: [
          IconButton(
            onPressed: _seeding ? null : _seedProductionSources,
            icon: _seeding
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            tooltip: strings.seedProductionSourcesButton,
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
              title: strings.tenderSourcesTitle,
            ),
          ),
          Expanded(
            child: sources.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyState(
                          icon: Icons.travel_explore_outlined,
                          title: strings.noTenderSourcesConfiguredMessage,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _seeding ? null : _seedProductionSources,
                          icon: _seeding
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_download_outlined,
                                  size: 18,
                                ),
                          label: Text(strings.seedProductionSourcesButton),
                        ),
                      ],
                    ),
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
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _SourceFormDialog(),
        ),
        tooltip: strings.addTenderSourceTitle,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SourceTile extends ConsumerStatefulWidget {
  const _SourceTile({required this.source});

  final TenderSource source;

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
          .read(tenderSyncServiceProvider)
          .runSource(widget.source.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.runCreatedOpportunities(created))),
        );
      }
    } on TenderSyncException catch (e) {
      _log.e('Tender source sync failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final source = widget.source;
    final isManual = source.discoveryMethod == TenderDiscoveryMethod.manual;

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: ListTile(
          onTap: () => pushSlideFade(
            context,
            TenderSourceWorkspaceScreen(sourceId: source.id),
          ),
          leading: CircleAvatar(
            backgroundColor: _statusColor(theme.colorScheme, source.status),
            radius: 6,
          ),
          title: Text(source.name),
          subtitle: Text(
            '${strings.tenderSourceCategoryLabel(source.category)} · '
            '${strings.tenderDiscoveryMethodLabel(source.discoveryMethod)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  source.status == TenderSourceStatus.paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                tooltip: source.status == TenderSourceStatus.paused
                    ? strings.resumeSourceButton
                    : strings.pauseSourceButton,
                onPressed: () {
                  final service = ref.read(tenderSourceServiceProvider);
                  if (source.status == TenderSourceStatus.paused) {
                    service.resume(source.id);
                  } else {
                    service.pause(source.id);
                  }
                },
              ),
              _running
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      tooltip: strings.runNowButton,
                      onPressed: isManual ? null : _runNow,
                    ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: strings.editTenderSourceTitle,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _SourceFormDialog(existing: source),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared Add/Edit form. [_ConnectorConfigFields] switches its visible
/// fields based on the selected [TenderDiscoveryMethod] — one form covers
/// every method rather than a separate dialog per method, since only the
/// connector-specific section changes.
class _SourceFormDialog extends ConsumerStatefulWidget {
  const _SourceFormDialog({this.existing});

  final TenderSource? existing;

  @override
  ConsumerState<_SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends ConsumerState<_SourceFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _organizationController = TextEditingController(
    text: widget.existing?.organization,
  );
  late final _countryController = TextEditingController(
    text: widget.existing?.country,
  );
  late final _websiteController = TextEditingController(
    text: widget.existing?.website,
  );
  late final _searchQueryController = TextEditingController(
    text: widget.existing?.searchQuery,
  );
  late final _tagsController = TextEditingController(
    text: widget.existing?.tags.join(', '),
  );
  late final _syncFrequencyController = TextEditingController(
    text: (widget.existing?.syncFrequencyMinutes ?? 1440).toString(),
  );

  // Connector-specific controllers — only the ones matching the selected
  // discoveryMethod are read on submit.
  late final _feedUrlController = TextEditingController(
    text: widget.existing?.connectorConfig['feedUrl'] as String?,
  );
  late final _pageUrlController = TextEditingController(
    text: widget.existing?.connectorConfig['pageUrl'] as String?,
  );
  late final _endpointUrlController = TextEditingController(
    text: widget.existing?.connectorConfig['endpointUrl'] as String?,
  );
  late final _itemSelectorController = TextEditingController(
    text:
        (widget.existing?.connectorConfig['selectors'] as Map?)?['item']
            as String?,
  );
  late final _titleSelectorController = TextEditingController(
    text:
        (widget.existing?.connectorConfig['selectors'] as Map?)?['title']
            as String?,
  );
  late final _sourceUrlSelectorController = TextEditingController(
    text:
        (widget.existing?.connectorConfig['selectors'] as Map?)?['sourceUrl']
            as String?,
  );
  late final _descriptionSelectorController = TextEditingController(
    text:
        (widget.existing?.connectorConfig['selectors'] as Map?)?['description']
            as String?,
  );
  late final _deadlineSelectorController = TextEditingController(
    text:
        (widget.existing?.connectorConfig['selectors'] as Map?)?['deadline']
            as String?,
  );

  late TenderSourceCategory _category =
      widget.existing?.category ?? TenderSourceCategory.governmentAgency;
  late TenderDiscoveryMethod _discoveryMethod =
      widget.existing?.discoveryMethod ?? TenderDiscoveryMethod.rss;
  late String _apiMode =
      (widget.existing?.connectorConfig['mode'] as String?) ?? 'aiSearch';

  bool _testing = false;
  String? _testResultMessage;
  bool? _testResultOk;

  @override
  void dispose() {
    _nameController.dispose();
    _organizationController.dispose();
    _countryController.dispose();
    _websiteController.dispose();
    _searchQueryController.dispose();
    _tagsController.dispose();
    _syncFrequencyController.dispose();
    _feedUrlController.dispose();
    _pageUrlController.dispose();
    _endpointUrlController.dispose();
    _itemSelectorController.dispose();
    _titleSelectorController.dispose();
    _sourceUrlSelectorController.dispose();
    _descriptionSelectorController.dispose();
    _deadlineSelectorController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildConnectorConfig() {
    switch (_discoveryMethod) {
      case TenderDiscoveryMethod.rss:
        return {'feedUrl': _feedUrlController.text.trim()};
      case TenderDiscoveryMethod.htmlScraping:
        return {
          'pageUrl': _pageUrlController.text.trim(),
          'selectors': {
            'item': _itemSelectorController.text.trim(),
            'title': _titleSelectorController.text.trim(),
            'sourceUrl': _sourceUrlSelectorController.text.trim(),
            'description': _descriptionSelectorController.text.trim(),
            'deadline': _deadlineSelectorController.text.trim(),
          },
        };
      case TenderDiscoveryMethod.api:
        return {
          'mode': _apiMode,
          if (_apiMode == 'restJson')
            'endpointUrl': _endpointUrlController.text.trim(),
        };
      case TenderDiscoveryMethod.email:
      case TenderDiscoveryMethod.manual:
        return {};
    }
  }

  TenderSource _buildDraft() {
    final now = DateTime.now();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final syncFrequency =
        int.tryParse(_syncFrequencyController.text.trim()) ?? 1440;

    return TenderSource(
      id: widget.existing?.id ?? '',
      name: _nameController.text.trim(),
      organization: _organizationController.text.trim(),
      category: _category,
      discoveryMethod: _discoveryMethod,
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      searchQuery: _searchQueryController.text.trim().isEmpty
          ? null
          : _searchQueryController.text.trim(),
      connectorConfig: _buildConnectorConfig(),
      authConfig: widget.existing?.authConfig ?? const {},
      status: widget.existing?.status ?? TenderSourceStatus.active,
      enabled: widget.existing?.enabled ?? true,
      syncFrequencyMinutes: syncFrequency,
      tags: tags,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResultMessage = null;
      _testResultOk = null;
    });
    final service = ref.read(tenderConnectionTestServiceProvider);
    final result = widget.existing != null
        ? await service.testSaved(widget.existing!.id)
        : await service.testDraft(_buildDraft());
    if (mounted) {
      setState(() {
        _testing = false;
        _testResultOk = result.ok;
        _testResultMessage = result.message;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final draft = _buildDraft();
    final service = ref.read(tenderSourceServiceProvider);
    if (widget.existing == null) {
      await service.create(draft);
    } else {
      await service.update(draft);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? strings.addTenderSourceTitle
            : strings.editTenderSourceTitle,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
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
              TextField(
                controller: _organizationController,
                decoration: InputDecoration(
                  labelText: strings.fieldOrganization,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TenderSourceCategory>(
                initialValue: _category,
                decoration: InputDecoration(labelText: strings.fieldCategory),
                items: TenderSourceCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(strings.tenderSourceCategoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TenderDiscoveryMethod>(
                initialValue: _discoveryMethod,
                decoration: InputDecoration(
                  labelText: strings.fieldDiscoveryMethod,
                ),
                items: TenderDiscoveryMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(strings.tenderDiscoveryMethodLabel(m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _discoveryMethod = v ?? _discoveryMethod;
                  _testResultMessage = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _countryController,
                decoration: InputDecoration(labelText: strings.fieldCountry),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _websiteController,
                decoration: InputDecoration(labelText: strings.fieldWebsite),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _searchQueryController,
                decoration: InputDecoration(
                  labelText: strings.fieldSearchQuery,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: strings.fieldTags,
                  hintText: 'agriculture, infrastructure',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _syncFrequencyController,
                decoration: InputDecoration(
                  labelText: strings.fieldSyncFrequency,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ConnectorConfigFields(
                method: _discoveryMethod,
                apiMode: _apiMode,
                onApiModeChanged: (v) => setState(() => _apiMode = v),
                feedUrlController: _feedUrlController,
                pageUrlController: _pageUrlController,
                endpointUrlController: _endpointUrlController,
                itemSelectorController: _itemSelectorController,
                titleSelectorController: _titleSelectorController,
                sourceUrlSelectorController: _sourceUrlSelectorController,
                descriptionSelectorController: _descriptionSelectorController,
                deadlineSelectorController: _deadlineSelectorController,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 18),
                    label: Text(
                      _testing
                          ? strings.testingConnectionLabel
                          : strings.testConnectionButton,
                    ),
                  ),
                ],
              ),
              if (_testResultMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _testResultMessage!,
                  style: TextStyle(
                    color: _testResultOk == true
                        ? AppStatusColors.success
                        : AppStatusColors.danger,
                  ),
                ),
              ],
            ],
          ),
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

/// Renders only the fields relevant to [method]. Stateless + wrapped in a
/// [Consumer] internally (rather than requiring the parent to pass
/// [AppStrings] down) so it can be dropped anywhere without plumbing.
class _ConnectorConfigFields extends StatelessWidget {
  const _ConnectorConfigFields({
    required this.method,
    required this.apiMode,
    required this.onApiModeChanged,
    required this.feedUrlController,
    required this.pageUrlController,
    required this.endpointUrlController,
    required this.itemSelectorController,
    required this.titleSelectorController,
    required this.sourceUrlSelectorController,
    required this.descriptionSelectorController,
    required this.deadlineSelectorController,
  });

  final TenderDiscoveryMethod method;
  final String apiMode;
  final ValueChanged<String> onApiModeChanged;
  final TextEditingController feedUrlController;
  final TextEditingController pageUrlController;
  final TextEditingController endpointUrlController;
  final TextEditingController itemSelectorController;
  final TextEditingController titleSelectorController;
  final TextEditingController sourceUrlSelectorController;
  final TextEditingController descriptionSelectorController;
  final TextEditingController deadlineSelectorController;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final strings = ref.watch(appStringsProvider);
        switch (method) {
          case TenderDiscoveryMethod.rss:
            return TextField(
              controller: feedUrlController,
              decoration: InputDecoration(labelText: strings.fieldFeedUrl),
            );
          case TenderDiscoveryMethod.htmlScraping:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: pageUrlController,
                  decoration: InputDecoration(labelText: strings.fieldPageUrl),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: itemSelectorController,
                  decoration: InputDecoration(
                    labelText: strings.fieldItemSelector,
                    hintText: '.tender-row',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleSelectorController,
                  decoration: InputDecoration(
                    labelText: strings.fieldTitleSelector,
                    hintText: '.tender-title',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: sourceUrlSelectorController,
                  decoration: InputDecoration(
                    labelText: strings.fieldSourceUrlSelector,
                    hintText: 'a.tender-link@href',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descriptionSelectorController,
                  decoration: InputDecoration(
                    labelText: strings.fieldDescriptionSelector,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: deadlineSelectorController,
                  decoration: InputDecoration(
                    labelText: strings.fieldDeadlineSelector,
                  ),
                ),
              ],
            );
          case TenderDiscoveryMethod.api:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: apiMode,
                  decoration: InputDecoration(
                    labelText: strings.fieldApiModeLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'aiSearch',
                      child: Text(strings.apiModeAiSearch),
                    ),
                    DropdownMenuItem(
                      value: 'restJson',
                      child: Text(strings.apiModeRestJson),
                    ),
                  ],
                  onChanged: (v) => onApiModeChanged(v ?? 'aiSearch'),
                ),
                if (apiMode == 'restJson') ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: endpointUrlController,
                    decoration: InputDecoration(
                      labelText: strings.fieldEndpointUrl,
                    ),
                  ),
                ],
              ],
            );
          case TenderDiscoveryMethod.email:
          case TenderDiscoveryMethod.manual:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
