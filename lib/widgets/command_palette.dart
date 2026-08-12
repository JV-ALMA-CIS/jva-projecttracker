import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_unit_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capability_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industry_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_article_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/product_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/service_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technology_workspace_screen.dart';
import 'package:jva_projecttracker/screens/applications/applications_screen.dart';
import 'package:jva_projecttracker/screens/documents/document_library_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_history_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_sources_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_inbox_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Opens the global command palette — a Spotlight/Ctrl+K-style modal that
/// jumps to any primary tab, opportunity, or Company Intelligence entity, or
/// fires a quick action, without walking the nested menus each of those
/// otherwise requires. All data comes from providers already watched
/// elsewhere in the app (opportunities/CI entity streams) — no new reads.
Future<void> showCommandPalette(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black45,
    builder: (context) => const _CommandPaletteDialog(),
  );
}

class _PaletteEntry {
  const _PaletteEntry({
    required this.icon,
    required this.label,
    required this.group,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String group;
  final VoidCallback onSelected;
}

class _CommandPaletteDialog extends ConsumerStatefulWidget {
  const _CommandPaletteDialog();

  @override
  ConsumerState<_CommandPaletteDialog> createState() =>
      _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<_CommandPaletteDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addEntity<T>(
    List<_PaletteEntry> entries,
    List<T> items,
    IconData icon,
    String group,
    String Function(T) nameOf,
    Widget Function(BuildContext, T) page,
  ) {
    for (final item in items) {
      entries.add(
        _PaletteEntry(
          icon: icon,
          label: nameOf(item),
          group: group,
          onSelected: () => pushSlideFade(context, page(context, item)),
        ),
      );
    }
  }

  List<_PaletteEntry> _buildEntries(AppStrings strings) {
    final entries = <_PaletteEntry>[];
    final goTo = strings.commandPaletteGoToGroup;
    final quickActions = strings.commandPaletteQuickActionsGroup;

    entries.addAll([
      _PaletteEntry(
        icon: Icons.dashboard_outlined,
        label: strings.navDashboard,
        group: goTo,
        onSelected: () => ref.read(selectedTabIndexProvider.notifier).index = 0,
      ),
      _PaletteEntry(
        icon: Icons.work_outline,
        label: strings.navProjects,
        group: goTo,
        onSelected: () => ref.read(selectedTabIndexProvider.notifier).index = 1,
      ),
      _PaletteEntry(
        icon: Icons.travel_explore_outlined,
        label: strings.navOpportunities,
        group: goTo,
        onSelected: () => ref.read(selectedTabIndexProvider.notifier).index = 2,
      ),
      _PaletteEntry(
        icon: Icons.insights_outlined,
        label: strings.navCompanyIntelligence,
        group: goTo,
        onSelected: () => ref.read(selectedTabIndexProvider.notifier).index = 3,
      ),
      _PaletteEntry(
        icon: Icons.send_outlined,
        label: strings.submissionsSectionTitle,
        group: goTo,
        onSelected: () => ref.read(selectedTabIndexProvider.notifier).index = 4,
      ),
    ]);

    entries.addAll([
      _PaletteEntry(
        icon: Icons.add,
        label: strings.newProjectTitle,
        group: quickActions,
        onSelected: () => pushSlideFade(context, const ProjectFormScreen()),
      ),
      _PaletteEntry(
        icon: Icons.travel_explore_outlined,
        label: strings.searchTooltip,
        group: quickActions,
        onSelected: () {
          ref.read(opportunityServiceProvider).triggerDiscoveryRun().catchError(
            (Object e) {
              _log.e('Opportunity discovery failed', error: e);
              return 0;
            },
          );
        },
      ),
      _PaletteEntry(
        icon: Icons.auto_awesome_outlined,
        label: strings.refreshRecommendationsButton,
        group: quickActions,
        onSelected: () {
          ref
              .read(recommendationEngineServiceProvider)
              .generateRecommendations()
              .catchError((Object e) {
                _log.e('Recommendation refresh failed', error: e);
                return 0;
              });
        },
      ),
      _PaletteEntry(
        icon: Icons.folder_open_outlined,
        label: strings.documentLibraryTitle,
        group: quickActions,
        onSelected: () => pushSlideFade(context, const DocumentLibraryScreen()),
      ),
      _PaletteEntry(
        icon: Icons.apps_outlined,
        label: strings.navApplications,
        group: quickActions,
        onSelected: () => pushSlideFade(context, const ApplicationsScreen()),
      ),
      _PaletteEntry(
        icon: Icons.inbox_outlined,
        label: strings.inboxTitle,
        group: quickActions,
        onSelected: () =>
            pushSlideFade(context, const OpportunityInboxScreen()),
      ),
      _PaletteEntry(
        icon: Icons.travel_explore,
        label: strings.discoverySourcesTitle,
        group: quickActions,
        onSelected: () =>
            pushSlideFade(context, const DiscoverySourcesScreen()),
      ),
      _PaletteEntry(
        icon: Icons.history,
        label: strings.discoveryHistoryTitle,
        group: quickActions,
        onSelected: () =>
            pushSlideFade(context, const DiscoveryHistoryScreen()),
      ),
    ]);

    for (final o in ref.watch(opportunitiesStreamProvider).value ?? const []) {
      entries.add(
        _PaletteEntry(
          icon: Icons.travel_explore_outlined,
          label: o.title,
          group: strings.commandPaletteOpportunitiesGroup,
          onSelected: () => pushSlideFade(
            context,
            OpportunityWorkspaceScreen(opportunityId: o.id),
          ),
        ),
      );
    }

    final opportunityById = {
      for (final o in ref.watch(opportunitiesStreamProvider).value ?? const [])
        o.id: o,
    };
    for (final p in ref.watch(proposalsStreamProvider).value ?? const []) {
      final opportunity = opportunityById[p.opportunityId];
      if (opportunity == null) continue;
      entries.add(
        _PaletteEntry(
          icon: Icons.description_outlined,
          label:
              '${opportunity.title} · ${strings.proposalStatusLabel(p.status)}',
          group: strings.commandPaletteProposalsGroup,
          onSelected: () => pushSlideFade(
            context,
            ProposalWorkspaceScreen(opportunityId: p.opportunityId),
          ),
        ),
      );
    }
    for (final s in ref.watch(submissionsStreamProvider).value ?? const []) {
      final opportunity = opportunityById[s.opportunityId];
      if (opportunity == null) continue;
      entries.add(
        _PaletteEntry(
          icon: Icons.send_outlined,
          label:
              '${opportunity.title} · ${strings.submissionStatusLabel(s.status)}',
          group: strings.commandPaletteSubmissionsGroup,
          onSelected: () => pushSlideFade(
            context,
            SubmissionWorkspaceScreen(opportunityId: s.opportunityId),
          ),
        ),
      );
    }

    final ciGroup = strings.commandPaletteCompanyIntelligenceGroup;
    _addEntity<BusinessUnit>(
      entries,
      ref.watch(businessUnitsStreamProvider).value ?? const [],
      Icons.apartment_outlined,
      ciGroup,
      (u) => u.name,
      (_, u) => BusinessUnitWorkspaceScreen(businessUnitId: u.id),
    );
    _addEntity<Product>(
      entries,
      ref.watch(productsStreamProvider).value ?? const [],
      Icons.inventory_2_outlined,
      ciGroup,
      (p) => p.name,
      (_, p) => ProductWorkspaceScreen(productId: p.id),
    );
    _addEntity<ServiceModel>(
      entries,
      ref.watch(servicesStreamProvider).value ?? const [],
      Icons.miscellaneous_services_outlined,
      ciGroup,
      (s) => s.name,
      (_, s) => ServiceWorkspaceScreen(serviceId: s.id),
    );
    _addEntity<Capability>(
      entries,
      ref.watch(capabilitiesStreamProvider).value ?? const [],
      Icons.extension_outlined,
      ciGroup,
      (c) => c.name,
      (_, c) => CapabilityWorkspaceScreen(capabilityId: c.id),
    );
    _addEntity<Technology>(
      entries,
      ref.watch(technologiesStreamProvider).value ?? const [],
      Icons.memory_outlined,
      ciGroup,
      (t) => t.name,
      (_, t) => TechnologyWorkspaceScreen(technologyId: t.id),
    );
    _addEntity<Industry>(
      entries,
      ref.watch(industriesStreamProvider).value ?? const [],
      Icons.factory_outlined,
      ciGroup,
      (i) => i.name,
      (_, i) => IndustryWorkspaceScreen(industryId: i.id),
    );
    _addEntity<Experience>(
      entries,
      ref.watch(experiencesStreamProvider).value ?? const [],
      Icons.military_tech_outlined,
      ciGroup,
      (e) => e.title,
      (_, e) => ExperienceWorkspaceScreen(experienceId: e.id),
    );
    _addEntity<KnowledgeArticle>(
      entries,
      ref.watch(knowledgeArticlesStreamProvider).value ?? const [],
      Icons.menu_book_outlined,
      ciGroup,
      (a) => a.title,
      (_, a) => KnowledgeArticleWorkspaceScreen(articleId: a.id),
    );

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final allEntries = _buildEntries(strings);
    final query = _query.trim().toLowerCase();

    // Keep the idle view lean (just destinations + quick actions); only
    // search into the potentially-large opportunity/CI entity lists once
    // the user actually types something.
    final visible = query.isEmpty
        ? allEntries
              .where(
                (e) =>
                    e.group == strings.commandPaletteGoToGroup ||
                    e.group == strings.commandPaletteQuickActionsGroup,
              )
              .toList()
        : allEntries
              .where((e) => e.label.toLowerCase().contains(query))
              .toList();

    final grouped = <String, List<_PaletteEntry>>{};
    for (final e in visible) {
      grouped.putIfAbsent(e.group, () => []).add(e);
    }

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: strings.commandPaletteHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(strings.commandPaletteNoResults),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final group in grouped.entries) ...[
                          Container(
                            width: double.infinity,
                            color: theme.colorScheme.surfaceContainerLow,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.lg,
                              AppSpacing.sm,
                            ),
                            child: Text(
                              group.key,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final e in group.value)
                            ListTile(
                              leading: Icon(e.icon),
                              title: Text(
                                e.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                e.onSelected();
                              },
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
