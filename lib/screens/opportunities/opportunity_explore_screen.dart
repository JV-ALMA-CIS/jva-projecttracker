import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/company_intelligence/certifications/certifications_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/services/opportunity_explore.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/fit_score_badge.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

/// The Explore tab (C1-C4): tenders outside Pipeline's strict wheelhouse —
/// cert-eligible, adjacent/growth, or unassigned-but-interesting — so they
/// stay visible instead of only living in "Unassigned". Same `Opportunity`
/// documents as every other tab (see `opportunity_explore.dart`'s module
/// doc); no second Firestore collection, no new required field. Kept
/// deliberately light per C5: a plain sorted list, no second facet wall.
class OpportunityExploreBody extends ConsumerWidget {
  const OpportunityExploreBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final opportunitiesAsync = ref.watch(opportunitiesStreamProvider);
    final certificationsAsync = ref.watch(certificationsStreamProvider);

    return opportunitiesAsync.when(
      data: (all) {
        final heldCertifications = certificationsAsync.value ?? const [];
        final candidates = exploreOpportunities(
          all,
          heldCertifications,
          now: DateTime.now(),
        );

        if (candidates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmptyState(
                    icon: Icons.explore_outlined,
                    title: strings.exploreEmptyTitle,
                    body: strings.exploreEmptyCaption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () =>
                        pushSlideFade(context, const CertificationsScreen()),
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: Text(strings.viewCertificationsCiButton),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          itemCount: candidates.length,
          itemBuilder: (context, i) {
            return FadeSlideIn(
              index: i,
              child: _ExploreTile(
                opportunity: candidates[i],
                heldCertifications: heldCertifications,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
    );
  }
}

class _ExploreTile extends ConsumerWidget {
  const _ExploreTile({
    required this.opportunity,
    required this.heldCertifications,
  });

  final Opportunity opportunity;
  final List<Certification> heldCertifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final now = DateTime.now();
    final certMatch = classifyExploreCertMatch(
      opportunity,
      heldCertifications,
      now: now,
    );
    final isGrowthMatch = matchesExploreGrowthKeyword(opportunity);

    final accentColor = switch (certMatch) {
      ExploreCertMatch.fullMatch => AppStatusColors.success,
      ExploreCertMatch.typeMatchWithGap => AppStatusColors.warning,
      ExploreCertMatch.none => AppStatusColors.info,
    };

    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          child: ListTile(
            leading: FitScoreBadge(
              percent: opportunity.fitScorePercent,
              size: 36,
            ),
            title: Text(
              opportunity.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                  children: [
                    if (certMatch == ExploreCertMatch.fullMatch)
                      StatusBadge(
                        icon: Icons.verified_outlined,
                        label: strings.certEligibleLabel,
                        color: AppStatusColors.success,
                      ),
                    if (certMatch == ExploreCertMatch.typeMatchWithGap)
                      StatusBadge(
                        icon: Icons.warning_amber_outlined,
                        label: strings.certGapLabel,
                        color: AppStatusColors.warning,
                      ),
                    if (isGrowthMatch)
                      StatusBadge(
                        icon: Icons.trending_up_outlined,
                        label: strings.growthOpportunityLabel,
                        color: AppStatusColors.info,
                      ),
                    if (opportunity.businessUnitIds.isEmpty)
                      StatusBadge(
                        label: strings.unassignedLabel,
                        color: AppStatusColors.neutral,
                      )
                    else
                      for (final buId in opportunity.businessUnitIds.take(2))
                        Consumer(
                          builder: (context, ref, _) {
                            final bu = ref
                                .watch(businessUnitByIdProvider(buId))
                                .value;
                            if (bu == null) return const SizedBox.shrink();
                            return StatusBadge(
                              label: bu.name,
                              color: AppStatusColors.neutral,
                            );
                          },
                        ),
                  ],
                ),
              ],
            ),
            onTap: () => pushSlideFade(
              context,
              OpportunityWorkspaceScreen(opportunityId: opportunity.id),
            ),
          ),
        ),
      ),
    );
  }
}
