import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/projects/import_project_from_document_dialog.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/project_card.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Which slice of `projectsStreamProvider` the Projects screen shows —
/// "Active delivery" (planned/running, see `isOperationalProject`) is the
/// governance-focused default; "Historical" is Phase 1's evidence-mode
/// imports (`ProjectStatus.past`); "All" is the pre-governance behavior,
/// unfiltered.
enum _ProjectsFilter { active, historical, all }

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  _ProjectsFilter? _filter;

  Future<void> _showAddOptions(BuildContext context, AppStrings strings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(strings.importProjectFromDocumentTitle),
                subtitle: Text(strings.importProjectFromDocumentCaption),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showImportProjectFromDocumentDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: Text(strings.newProjectTitle),
                subtitle: Text(strings.newProjectManualCaption),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  pushSlideFade(context, const ProjectFormScreen());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final projects = ref.watch(projectsStreamProvider);
    final operational = ref.watch(operationalProjectsProvider);
    final historical = ref.watch(historicalProjectsProvider);

    // Default: "Active delivery" once any operational project exists,
    // otherwise "All" — never defaults to a tab that would show an empty
    // state on first load when the portfolio is still all-historical (or
    // empty), per the brief's "Default tab: Active delivery if any exist,
    // else All" rule. Only decided once (`_filter == null`), so a later
    // user tap always wins even if operational.isEmpty flips afterward.
    _filter ??= operational.isNotEmpty
        ? _ProjectsFilter.active
        : _ProjectsFilter.all;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context, strings),
        tooltip: strings.addButton,
        child: const Icon(Icons.add),
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
              icon: Icons.inventory_2_outlined,
              title: strings.projectsTitle,
              subtitle: strings.projectsSubtitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: SegmentedButton<_ProjectsFilter>(
              segments: [
                ButtonSegment(
                  value: _ProjectsFilter.active,
                  label: Text(strings.activeDeliveryTabLabel),
                  icon: const Icon(Icons.construction_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _ProjectsFilter.historical,
                  label: Text(strings.historicalTabLabel),
                  icon: const Icon(Icons.history_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _ProjectsFilter.all,
                  label: Text(strings.filterAllLabel),
                ),
              ],
              selected: {_filter!},
              onSelectionChanged: (selected) =>
                  setState(() => _filter = selected.first),
            ),
          ),
          Expanded(
            child: projects.when(
              data: (all) {
                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.noProjectsYet,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                showImportProjectFromDocumentDialog(context),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(strings.importProjectFromDocumentTitle),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => pushSlideFade(
                              context,
                              const ProjectFormScreen(),
                            ),
                            child: Text(strings.newProjectTitle),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final list = switch (_filter!) {
                  _ProjectsFilter.active => operational,
                  _ProjectsFilter.historical => historical,
                  _ProjectsFilter.all => all,
                };

                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _filter == _ProjectsFilter.active
                          ? strings.noActiveDeliveryProjectsMessage
                          : strings.noHistoricalProjectsMessage,
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return AdaptiveListGrid(
                  items: list,
                  // Taller than the 148 default: ProjectCard's meta-chip Wrap
                  // can now grow to a second row once a project has been
                  // extraction-linked to a source opportunity and/or
                  // promoted experience (sourceOpportunityChipLabel /
                  // linkedExperienceChipLabel), on top of its usual
                  // category/role/value chips.
                  tileHeight: 172,
                  itemBuilder: (context, p) => ProjectCard(
                    project: p,
                    onTap: () => pushSlideFade(
                      context,
                      ProjectWorkspaceScreen(projectId: p.id),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
            ),
          ),
        ],
      ),
    );
  }
}
