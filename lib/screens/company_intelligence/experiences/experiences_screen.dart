import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ExperienceStatus status) => switch (status) {
  ExperienceStatus.active => AppStatusColors.success,
  ExperienceStatus.archived => AppStatusColors.neutral,
};

class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ExperienceStatus? _statusFilter;
  String? _countryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Experience> _applyFilters(List<Experience> experiences) {
    final query = _query.trim().toLowerCase();
    return experiences.where((e) {
      if (_statusFilter != null && e.status != _statusFilter) return false;
      if (_countryFilter != null && e.country != _countryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          e.summary.toLowerCase().contains(query) ||
          (e.clientName?.toLowerCase().contains(query) ?? false) ||
          (e.partnerName?.toLowerCase().contains(query) ?? false) ||
          e.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final experiencesAsync = ref.watch(experiencesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // heroTag: null avoids a hero-tag collision with other screens'
        // FABs when two Scaffolds are briefly mounted together (e.g.
        // HomeShell's tab-switch AnimatedSwitcher).
        heroTag: null,
        onPressed: () => pushSlideFade(context, const ExperienceFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: experiencesAsync.when(
          data: (experiences) {
            if (experiences.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      leading: PageBackButton(),
                      icon: Icons.military_tech_outlined,
                      title: strings.experiencesTitle,
                      subtitle: strings.experiencesSubtitle,
                      accentColor: AppEntityColors.experience,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.military_tech_outlined,
                      title: strings.noExperiencesYet,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          const ExperienceFormScreen(),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newExperienceTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final countries = {
              for (final e in experiences)
                if (e.country != null && e.country!.isNotEmpty) e.country!,
            }.toList()..sort();
            final filtered = _applyFilters(experiences);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: PageHeader(
                    leading: PageBackButton(),
                    icon: Icons.military_tech_outlined,
                    title: strings.experiencesTitle,
                    subtitle: strings.experiencesSubtitle,
                    accentColor: AppEntityColors.experience,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: strings.searchExperiencesHint,
                    leading: const Icon(Icons.search),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilterChip(
                        label: Text(strings.filterAllLabel),
                        selected: _statusFilter == null,
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      for (final s in ExperienceStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                      for (final country in countries)
                        FilterChip(
                          label: Text(country),
                          selected: _countryFilter == country,
                          onSelected: (selected) => setState(
                            () => _countryFilter = selected ? country : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noExperiencesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, e) => EntityCard(
                            title: e.title,
                            subtitle: e.clientName?.isNotEmpty == true
                                ? e.clientName
                                : e.summary,
                            statusBadge: StatusBadge(
                              label: e.status.label,
                              color: _statusColor(e.status),
                            ),
                            accentColor: AppEntityColors.experience,
                            metaChips: [
                              if (e.country != null && e.country!.isNotEmpty)
                                Chip(
                                  label: Text(e.country!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ...e.tags.map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              ExperienceWorkspaceScreen(experienceId: e.id),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(strings.errorPrefix(error))),
        ),
      ),
    );
  }
}
