import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_dashboard_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_sources_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_inbox_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/services/business_unit_seed_service.dart';
import 'package:jva_projecttracker/services/delivery_and_wins.dart';
import 'package:jva_projecttracker/services/opportunity_business_unit_backfill_service.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/pipeline_stage_badge.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger();

/// The three tabs replacing what used to be five separate full-page
/// destinations reachable only via small unlabeled AppBar icons (Inbox,
/// Discovery Dashboard, Discovery Sources, Tender Sources). Discovery
/// Sources/History (the pre-Tender-source discovery system) are no longer
/// linked from here — the code's own comments already called for their
/// retirement once Milestone 3.8c (Tender Source Workspace) shipped, which
/// it has; their one real remaining feature, "add opportunity manually",
/// moved to the Pipeline tab below instead of being lost.
const _kTabColors = [
  AppStatusColors.info,
  AppStatusColors.warning,
  AppStatusColors.ai,
];

class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );
  bool _searching = false;
  bool _backfilling = false;
  bool _seedingBusinessUnits = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runDiscovery() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _searching = true);
    try {
      final created = await ref
          .read(opportunityServiceProvider)
          .triggerDiscoveryRun();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.foundOpportunities(created))),
        );
      }
    } catch (e) {
      _log.e('Opportunity discovery failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.searchFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Admin-only setup step — run this BEFORE the backfill button below.
  /// Ensures the canonical Business Unit catalog (Construction, Facility
  /// Management, Agribusiness, Information Technology, Human Resources)
  /// exists so classification/backfill have real entries to match against
  /// — see `functions/seedCompanyBusinessUnits.js`. Same not-role-gated-
  /// client-side pattern as `TenderSourcesScreen`'s "Seed Production
  /// Sources" action.
  Future<void> _seedBusinessUnits() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _seedingBusinessUnits = true);
    try {
      final result = await ref
          .read(businessUnitSeedServiceProvider)
          .seedCanonicalBusinessUnits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.businessUnitSeedResultMessage(
                result.created,
                result.skipped,
              ),
            ),
          ),
        );
      }
    } on BusinessUnitSeedException catch (e) {
      _log.e('Business unit seeding failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
      }
    } finally {
      if (mounted) setState(() => _seedingBusinessUnits = false);
    }
  }

  /// Admin-only bulk action — see `functions/backfillOpportunityBusinessUnits.js`.
  /// Not role-gated client-side (mirrors `TenderSourcesScreen`'s "Seed
  /// Production Sources" action): a non-admin caller simply gets a
  /// `permission-denied` error back from the callable itself, same as every
  /// other admin-only write path in this app.
  Future<void> _runBusinessUnitBackfill() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _backfilling = true);
    try {
      final result = await ref
          .read(opportunityBusinessUnitBackfillServiceProvider)
          .run();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.businessUnitBackfillResultMessage(
                result.updated,
                result.skipped,
              ),
            ),
          ),
        );
      }
    } on OpportunityBusinessUnitBackfillException catch (e) {
      _log.e('Business unit backfill failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
      }
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => showManualOpportunityDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: strings.addOpportunityManuallyTitle,
          ),
          IconButton(
            onPressed: _searching ? null : _runDiscovery,
            icon: _searching
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_outlined),
            tooltip: strings.searchTooltip,
          ),
          IconButton(
            onPressed: _seedingBusinessUnits ? null : _seedBusinessUnits,
            icon: _seedingBusinessUnits
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.apartment_outlined),
            tooltip: strings.seedBusinessUnitsTooltip,
          ),
          IconButton(
            onPressed: _backfilling ? null : _runBusinessUnitBackfill,
            icon: _backfilling
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_tree_outlined),
            tooltip: strings.assignBusinessUnitsTooltip,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.view_kanban_outlined, color: _kTabColors[0]),
              child: Text(
                strings.opportunitiesTitle,
                style: TextStyle(color: _kTabColors[0]),
              ),
            ),
            Tab(
              icon: Icon(Icons.inbox_outlined, color: _kTabColors[1]),
              child: Text(
                strings.inboxTitle,
                style: TextStyle(color: _kTabColors[1]),
              ),
            ),
            Tab(
              icon: Icon(
                Icons.dashboard_customize_outlined,
                color: _kTabColors[2],
              ),
              child: Text(
                strings.discoveryDashboardTitle,
                style: TextStyle(color: _kTabColors[2]),
              ),
            ),
          ],
        ),
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
              title: strings.opportunitiesTitle,
              subtitle: strings.opportunitiesSubtitle,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PipelineTab(
                  searching: _searching,
                  onRunDiscovery: _runDiscovery,
                ),
                const OpportunityInboxBody(),
                const DiscoveryDashboardBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Pipeline tab's content: Business Unit selector (All | one per active
/// BU | Unassigned) as the primary partition, then a faceted filter bar
/// (search, stage, value band, deadline window, fit score, buyer type)
/// applied on top, composed via `filterOpportunities` — see
/// `services/opportunity_filters.dart`. All filtering is client-side over
/// the already-streamed `opportunitiesStreamProvider` list; no new
/// Firestore reads. Filter state lives in this widget so it survives
/// switching to another tab and back, but is lost on navigating away from
/// the Opportunities screen entirely — same lifetime as any other
/// ConsumerStatefulWidget's local state in this app.
class _PipelineTab extends ConsumerStatefulWidget {
  const _PipelineTab({required this.searching, required this.onRunDiscovery});

  final bool searching;
  final VoidCallback onRunDiscovery;

  @override
  ConsumerState<_PipelineTab> createState() => _PipelineTabState();
}

class _PipelineTabState extends ConsumerState<_PipelineTab> {
  final _searchController = TextEditingController();
  OpportunityBuFilter _buFilter = const OpportunityBuFilter.all();
  OpportunityFacetFilters _facets = const OpportunityFacetFilters();
  bool _filtersExpanded = false;
  bool _wonOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _buFilter = const OpportunityBuFilter.all();
      _facets = const OpportunityFacetFilters();
      _searchController.clear();
      _wonOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final opportunitiesAsync = ref.watch(opportunitiesStreamProvider);
    final businessUnitsAsync = ref.watch(businessUnitsStreamProvider);

    return opportunitiesAsync.when(
      data: (all) {
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.travel_explore_outlined,
            title: strings.noOpportunitiesDiscovered,
            action: FilledButton.icon(
              onPressed: widget.searching ? null : widget.onRunDiscovery,
              icon: const Icon(Icons.travel_explore_outlined),
              label: Text(strings.searchNowButton),
            ),
          );
        }

        final businessUnits = businessUnitsAsync.value ?? const [];
        final buFiltered = all
            .where((o) => matchesBuFilter(o, _buFilter))
            .toList();
        final wonFiltered = _wonOnly
            ? buFiltered.where(isWonOpportunity).toList()
            : buFiltered;
        final filtered = filterOpportunities(
          wonFiltered,
          const OpportunityBuFilter.all(),
          _facets,
          now: DateTime.now(),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _BuSelector(
                businessUnits: businessUnits,
                selected: _buFilter,
                onSelected: (f) => setState(() => _buFilter = f),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: strings.searchOpportunitiesHint,
                      leading: const Icon(Icons.search),
                      onChanged: (v) => setState(
                        () => _facets = _facets.copyWith(searchQuery: v),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                    tooltip: strings.filtersButtonLabel,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: Text(strings.awardedWonFilterLabel),
                  selected: _wonOnly,
                  onSelected: (selected) => setState(() => _wonOnly = selected),
                ),
              ),
            ),
            if (_filtersExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: SingleChildScrollView(
                  child: _FacetFilterBar(
                    strings: strings,
                    facets: _facets,
                    onChanged: (f) => setState(() => _facets = f),
                    onClear: _clearFilters,
                  ),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title:
                          _buFilter.selection != OpportunityBuSelection.all &&
                              _facets.isEmpty
                          ? strings.noOpportunitiesInBusinessUnit
                          : strings.noOpportunitiesMatchFilters,
                      action: TextButton(
                        onPressed: _clearFilters,
                        child: Text(strings.clearFiltersButton),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final opportunity = filtered[i];
                        return FadeSlideIn(
                          index: i,
                          child: _OpportunitiesTile(opportunity: opportunity),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
    );
  }
}

/// Business Unit chip row — "All" and "Unassigned" are always shown
/// alongside one chip per active [BusinessUnit] from
/// `businessUnitsStreamProvider`. Never invents a Business Unit: an empty
/// `businessUnits` list just means no BU-specific chips render, and
/// "Unassigned" still honestly reflects opportunities with empty
/// `businessUnitIds`.
class _BuSelector extends StatelessWidget {
  const _BuSelector({
    required this.businessUnits,
    required this.selected,
    required this.onSelected,
  });

  final List<BusinessUnit> businessUnits;
  final OpportunityBuFilter selected;
  final ValueChanged<OpportunityBuFilter> onSelected;

  bool _isSelected(OpportunityBuSelection selection, [String? id]) {
    if (selected.selection != selection) return false;
    if (selection == OpportunityBuSelection.specific) {
      return selected.businessUnitId == id;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(strings.filterAllLabel),
            selected: _isSelected(OpportunityBuSelection.all),
            onSelected: (_) => onSelected(const OpportunityBuFilter.all()),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final bu in businessUnits) ...[
            ChoiceChip(
              label: Text(bu.name),
              selected: _isSelected(OpportunityBuSelection.specific, bu.id),
              onSelected: (_) =>
                  onSelected(OpportunityBuFilter.specific(bu.id)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          ChoiceChip(
            label: Text(strings.unassignedLabel),
            selected: _isSelected(OpportunityBuSelection.unassigned),
            onSelected: (_) =>
                onSelected(const OpportunityBuFilter.unassigned()),
          ),
        ],
      ),
    );
  }
}

/// The faceted filter row (stage, value, deadline, fit score, buyer type) —
/// shown below the search bar. Each facet is its own `Wrap` of
/// `FilterChip`s so a user can see and change every active filter without
/// opening a separate sheet/dialog, matching the pattern already used by
/// `experiences_screen.dart`.
class _FacetFilterBar extends StatelessWidget {
  const _FacetFilterBar({
    required this.strings,
    required this.facets,
    required this.onChanged,
    required this.onClear,
  });

  final AppStrings strings;
  final OpportunityFacetFilters facets;
  final ValueChanged<OpportunityFacetFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: Text(strings.filterAllLabel),
              selected: facets.stage == null,
              onSelected: (_) => onChanged(facets.copyWith(clearStage: true)),
            ),
            for (final stage in OpportunityPipelineStage.values)
              FilterChip(
                label: Text(strings.pipelineStageLabel(stage)),
                selected: facets.stage == stage,
                onSelected: (selected) => onChanged(
                  selected
                      ? facets.copyWith(stage: stage)
                      : facets.copyWith(clearStage: true),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final band in ValueBand.values)
              FilterChip(
                label: Text(_valueBandLabel(strings, band)),
                selected: facets.valueBand == band,
                onSelected: (selected) => onChanged(
                  facets.copyWith(valueBand: selected ? band : ValueBand.any),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final window in DeadlineWindow.values)
              FilterChip(
                label: Text(_deadlineWindowLabel(strings, window)),
                selected: facets.deadlineWindow == window,
                onSelected: (selected) => onChanged(
                  facets.copyWith(
                    deadlineWindow: selected ? window : DeadlineWindow.any,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final threshold in FitScoreThreshold.values)
              FilterChip(
                label: Text(_fitScoreThresholdLabel(strings, threshold)),
                selected: facets.fitScoreThreshold == threshold,
                onSelected: (selected) => onChanged(
                  facets.copyWith(
                    fitScoreThreshold: selected
                        ? threshold
                        : FitScoreThreshold.any,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final facet in BuyerTypeFacet.values)
              FilterChip(
                label: Text(_buyerTypeFacetLabel(strings, facet)),
                selected: facets.buyerType == facet,
                onSelected: (selected) => onChanged(
                  facets.copyWith(
                    buyerType: selected ? facet : BuyerTypeFacet.any,
                  ),
                ),
              ),
            if (!facets.isEmpty)
              TextButton(
                onPressed: onClear,
                child: Text(strings.clearFiltersButton),
              ),
          ],
        ),
      ],
    );
  }
}

String _valueBandLabel(AppStrings strings, ValueBand band) => switch (band) {
  ValueBand.any => strings.filterAllLabel,
  ValueBand.under50k => strings.valueBandUnder50k,
  ValueBand.from50kTo250k => strings.valueBandFrom50kTo250k,
  ValueBand.from250kTo1m => strings.valueBandFrom250kTo1m,
  ValueBand.over1m => strings.valueBandOver1m,
  ValueBand.unknown => strings.valueBandUnknown,
};

String _deadlineWindowLabel(AppStrings strings, DeadlineWindow window) =>
    switch (window) {
      DeadlineWindow.any => strings.filterAllLabel,
      DeadlineWindow.overdue => strings.deadlineOverdueFilterLabel,
      DeadlineWindow.within7Days => strings.deadlineWithin7DaysLabel,
      DeadlineWindow.within14Days => strings.deadlineWithin14DaysLabel,
      DeadlineWindow.within30Days => strings.deadlineWithin30DaysLabel,
      DeadlineWindow.noDeadline => strings.deadlineNoneFilterLabel,
    };

String _fitScoreThresholdLabel(AppStrings strings, FitScoreThreshold t) =>
    switch (t) {
      FitScoreThreshold.any => strings.filterAllLabel,
      FitScoreThreshold.at50 => '≥50',
      FitScoreThreshold.at70 => '≥70',
      FitScoreThreshold.at85 => '≥85',
    };

String _buyerTypeFacetLabel(AppStrings strings, BuyerTypeFacet facet) =>
    switch (facet) {
      BuyerTypeFacet.any => strings.filterAllLabel,
      BuyerTypeFacet.government => strings.buyerTypeGovernment,
      BuyerTypeFacet.developmentPartner => strings.buyerTypeDevelopmentPartner,
      BuyerTypeFacet.unAgency => strings.buyerTypeUnAgency,
      BuyerTypeFacet.ngo => strings.buyerTypeNgo,
      BuyerTypeFacet.privateSector => strings.buyerTypePrivateSector,
      BuyerTypeFacet.unknown => strings.buyerTypeUnknown,
    };

Color _riskColor(RiskLevel r) => switch (r) {
  RiskLevel.low => AppStatusColors.success,
  RiskLevel.medium => AppStatusColors.warning,
  RiskLevel.high => AppStatusColors.danger,
};

Color _priorityColor(OpportunityPriority p) => switch (p) {
  OpportunityPriority.low => Colors.grey,
  OpportunityPriority.medium => AppStatusColors.info,
  OpportunityPriority.high => AppStatusColors.warning,
};

/// A color for the Pipeline tile's left accent, keyed to fit score tier —
/// the single most useful "should I look at this" signal on this list, so
/// it's the one that gets the color rather than pipeline stage (which
/// already has its own badge below).
Color _fitColor(int fitScorePercent) {
  if (fitScorePercent >= 70) return AppStatusColors.success;
  if (fitScorePercent >= 40) return AppStatusColors.warning;
  return Colors.grey;
}

class _OpportunitiesTile extends ConsumerWidget {
  const _OpportunitiesTile({required this.opportunity});

  final Opportunity opportunity;

  int get _relatedKnowledgeCount =>
      opportunity.industryIds.length +
      opportunity.technologyIds.length +
      opportunity.businessUnitIds.length +
      opportunity.productIds.length +
      opportunity.serviceIds.length +
      opportunity.capabilityIds.length +
      opportunity.experienceIds.length +
      opportunity.knowledgeArticleIds.length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final accentColor = _fitColor(opportunity.fitScorePercent);
    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          child: ExpansionTile(
            leading: FitScoreBadge(
              percent: opportunity.fitScorePercent,
              size: 36,
            ),
            title: Text(opportunity.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opportunity.client ?? opportunity.sourceUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: pipelineStageColor(
                          opportunity.pipelineStage,
                        ),
                      ),
                      label: Text(
                        strings.pipelineStageLabel(opportunity.pipelineStage),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    if (isWonOpportunity(opportunity))
                      Consumer(
                        builder: (context, ref, _) {
                          final linkedProject = ref
                              .watch(
                                projectByOpportunityIdProvider(opportunity.id),
                              )
                              .value;
                          final started = linkedProject != null;
                          return Chip(
                            avatar: Icon(
                              started
                                  ? Icons.check_circle_outline
                                  : Icons.play_circle_outline,
                              size: 14,
                              color: started
                                  ? AppStatusColors.success
                                  : AppStatusColors.warning,
                            ),
                            label: Text(
                              started
                                  ? strings.projectStartedLabel
                                  : strings.startProjectNeededLabel,
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        },
                      ),
                    for (final buId in opportunity.businessUnitIds.take(2))
                      Consumer(
                        builder: (context, ref, _) {
                          final bu = ref
                              .watch(businessUnitByIdProvider(buId))
                              .value;
                          if (bu == null) return const SizedBox.shrink();
                          return Chip(
                            label: Text(bu.name),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        },
                      ),
                    if (opportunity.estimatedBudget != null)
                      Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 14),
                        label: Text(
                          opportunity.estimatedBudget!.toStringAsFixed(0),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (opportunity.deadline != null)
                      Chip(
                        avatar: const Icon(Icons.event_outlined, size: 14),
                        label: Text(
                          '${opportunity.deadline!.year}-${opportunity.deadline!.month.toString().padLeft(2, '0')}-${opportunity.deadline!.day.toString().padLeft(2, '0')}',
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (buyerTypeFacetFor(opportunity) !=
                        BuyerTypeFacet.unknown)
                      Chip(
                        avatar: const Icon(
                          Icons.account_balance_outlined,
                          size: 14,
                        ),
                        label: Text(
                          _buyerTypeFacetLabel(
                            strings,
                            buyerTypeFacetFor(opportunity),
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opportunity.description),
                    const SizedBox(height: 8),
                    if (opportunity.fitReasoning.isNotEmpty) ...[
                      Text(
                        strings.fitReasoningLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(opportunity.fitReasoning),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      children: opportunity.tags
                          .map((t) => Chip(label: Text(t)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.editClassificationTitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: pipelineStageColor(
                              opportunity.pipelineStage,
                            ),
                          ),
                          label: Text(
                            strings.pipelineStageLabel(
                              opportunity.pipelineStage,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            strings.classificationStatusLabel(
                              opportunity.classificationStatus,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (opportunity.confidenceScore != null)
                          Chip(
                            label: Text(
                              strings.confidenceScoreChipLabel(
                                opportunity.confidenceScore!,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (opportunity.priority != null)
                          Chip(
                            avatar: CircleAvatar(
                              backgroundColor: _priorityColor(
                                opportunity.priority!,
                              ),
                            ),
                            label: Text(
                              strings.opportunityPriorityLabel(
                                opportunity.priority!,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (opportunity.riskLevel != null)
                          Chip(
                            avatar: CircleAvatar(
                              backgroundColor: _riskColor(
                                opportunity.riskLevel!,
                              ),
                            ),
                            label: Text(
                              strings.riskLevelLabel(opportunity.riskLevel!),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (_relatedKnowledgeCount > 0)
                          Chip(
                            label: Text(
                              strings.relatedKnowledgeCount(
                                _relatedKnowledgeCount,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (opportunity.overallMatchScore != null)
                          Chip(
                            label: Text(
                              '${strings.overallMatchScoreLabel}: '
                              '${opportunity.overallMatchScore}%',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (opportunity.sourceUrl.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                launchUrl(Uri.parse(opportunity.sourceUrl)),
                            child: Text(strings.openSourceButton),
                          ),
                        FilledButton.icon(
                          onPressed: () => pushSlideFade(
                            context,
                            OpportunityWorkspaceScreen(
                              opportunityId: opportunity.id,
                            ),
                          ),
                          icon: const Icon(Icons.workspaces_outlined, size: 18),
                          label: Text(strings.openWorkspaceButton),
                        ),
                        if (isWonOpportunity(opportunity))
                          Consumer(
                            builder: (context, ref, _) {
                              final linkedProject = ref
                                  .watch(
                                    projectByOpportunityIdProvider(
                                      opportunity.id,
                                    ),
                                  )
                                  .value;
                              if (linkedProject == null) {
                                return const SizedBox.shrink();
                              }
                              return OutlinedButton.icon(
                                onPressed: () => pushSlideFade(
                                  context,
                                  ProjectWorkspaceScreen(
                                    projectId: linkedProject.id,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.construction_outlined,
                                  size: 18,
                                ),
                                label: Text(strings.openProjectButton),
                              );
                            },
                          ),
                        DropdownButton<OpportunityStatus>(
                          value: opportunity.status,
                          items: OpportunityStatus.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    strings.opportunityStatusLabel(s),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (s) {
                            if (s != null) {
                              ref
                                  .read(opportunityServiceProvider)
                                  .updateStatus(opportunity.id, s);
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
        ),
      ),
    );
  }
}
