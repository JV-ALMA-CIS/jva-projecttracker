import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_engine_service.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/recommendation_card.dart';

/// The full AI Recommendations feed — a daily-use triage list for
/// executives/BD managers, backed by the portfolio-wide
/// `generateRecommendations` Cloud Function. Unlike the read-only
/// classification/match-analysis/strategic-review screens (each a report on
/// one opportunity), this is an actionable list: a user can dismiss a
/// recommendation or mark it actioned, which only changes this entity's own
/// lifecycle status — see ADR-006.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  bool _refreshing = false;
  RecommendationStatus _filter = RecommendationStatus.active;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final strings = ref.read(appStringsProvider);
    try {
      final created = await ref
          .read(recommendationEngineServiceProvider)
          .generateRecommendations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.recommendationsRefreshSucceeded(created)),
          ),
        );
      }
    } on RecommendationEngineException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.recommendationsRefreshFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _dismiss(String id) async {
    final strings = ref.read(appStringsProvider);
    await ref.read(recommendationServiceProvider).dismiss(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.recommendationDismissed)));
    }
  }

  Future<void> _markActioned(String id) async {
    final strings = ref.read(appStringsProvider);
    await ref.read(recommendationServiceProvider).markActioned(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.recommendationActioned)));
    }
  }

  List<Recommendation> _visibleRecommendations(AppStrings strings) {
    if (_filter == RecommendationStatus.active) {
      return ref.watch(activeRecommendationsProvider);
    }
    final all = ref.watch(recommendationsStreamProvider).value ?? const [];
    return all.where((r) => r.status == _filter).toList();
  }

  String _emptyStateFor(AppStrings strings, RecommendationStatus filter) {
    return switch (filter) {
      RecommendationStatus.active => strings.noActiveRecommendations,
      RecommendationStatus.actioned => strings.noActionedRecommendations,
      RecommendationStatus.dismissed => strings.noDismissedRecommendations,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final recommendations = _visibleRecommendations(strings);

    return Scaffold(
      appBar: AppBar(),
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
              icon: Icons.auto_awesome_outlined,
              title: strings.recommendationsScreenTitle,
              subtitle: null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _refreshing ? null : _refresh,
                      icon: _refreshing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(strings.refreshRecommendationsButton),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(strings.filterActiveLabel),
                      selected: _filter == RecommendationStatus.active,
                      onSelected: (_) =>
                          setState(() => _filter = RecommendationStatus.active),
                    ),
                    ChoiceChip(
                      label: Text(strings.filterActionedLabel),
                      selected: _filter == RecommendationStatus.actioned,
                      onSelected: (_) => setState(
                        () => _filter = RecommendationStatus.actioned,
                      ),
                    ),
                    ChoiceChip(
                      label: Text(strings.filterDismissedLabel),
                      selected: _filter == RecommendationStatus.dismissed,
                      onSelected: (_) => setState(
                        () => _filter = RecommendationStatus.dismissed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (recommendations.isEmpty)
                  EmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: _emptyStateFor(strings, _filter),
                    compact: true,
                  )
                else
                  for (final (i, recommendation) in recommendations.indexed)
                    FadeSlideIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: RecommendationCard(
                          recommendation: recommendation,
                          onDismiss:
                              recommendation.status ==
                                  RecommendationStatus.active
                              ? () => _dismiss(recommendation.id)
                              : null,
                          onMarkActioned:
                              recommendation.status ==
                                  RecommendationStatus.active
                              ? () => _markActioned(recommendation.id)
                              : null,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
