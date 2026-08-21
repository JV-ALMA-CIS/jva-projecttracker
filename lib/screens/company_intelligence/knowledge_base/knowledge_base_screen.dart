import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_article_workspace_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(KnowledgeArticleStatus status) => switch (status) {
  KnowledgeArticleStatus.active => AppStatusColors.success,
  KnowledgeArticleStatus.archived => AppStatusColors.neutral,
};

class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseScreen> createState() =>
      _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  KnowledgeArticleStatus? _statusFilter;
  String? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<KnowledgeArticle> _applyFilters(List<KnowledgeArticle> articles) {
    final query = _query.trim().toLowerCase();
    return articles.where((a) {
      if (_statusFilter != null && a.status != _statusFilter) return false;
      if (_categoryFilter != null && a.category != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return a.title.toLowerCase().contains(query) ||
          a.summary.toLowerCase().contains(query) ||
          a.content.toLowerCase().contains(query) ||
          a.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final articlesAsync = ref.watch(knowledgeArticlesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // heroTag: null avoids a hero-tag collision with other screens'
        // FABs when two Scaffolds are briefly mounted together (e.g.
        // HomeShell's tab-switch AnimatedSwitcher).
        heroTag: null,
        onPressed: () => pushSlideFade(context, const KnowledgeFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: articlesAsync.when(
          data: (articles) {
            if (articles.isEmpty) {
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
                      icon: Icons.menu_book_outlined,
                      title: strings.knowledgeBaseTitle,
                      subtitle: strings.knowledgeBaseSubtitle,
                      accentColor: AppEntityColors.knowledgeBase,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: strings.noKnowledgeArticlesYet,
                      action: FilledButton.icon(
                        onPressed: () =>
                            pushSlideFade(context, const KnowledgeFormScreen()),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newKnowledgeArticleTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final categories = {
              for (final a in articles)
                if (a.category.isNotEmpty) a.category,
            }.toList()..sort();
            final filtered = _applyFilters(articles);

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
                    icon: Icons.menu_book_outlined,
                    title: strings.knowledgeBaseTitle,
                    subtitle: strings.knowledgeBaseSubtitle,
                    accentColor: AppEntityColors.knowledgeBase,
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
                    hintText: strings.searchKnowledgeHint,
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
                      for (final s in KnowledgeArticleStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                      for (final category in categories)
                        FilterChip(
                          label: Text(category),
                          selected: _categoryFilter == category,
                          onSelected: (selected) => setState(
                            () => _categoryFilter = selected ? category : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noKnowledgeArticlesMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, a) => EntityCard(
                            title: a.title,
                            subtitle: a.summary,
                            statusBadge: StatusBadge(
                              label: a.status.label,
                              color: _statusColor(a.status),
                            ),
                            accentColor: AppEntityColors.knowledgeBase,
                            metaChips: [
                              if (a.category.isNotEmpty)
                                Chip(
                                  label: Text(a.category),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ...a.tags.map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              KnowledgeArticleWorkspaceScreen(articleId: a.id),
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
