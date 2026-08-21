import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_units_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capabilities_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/certifications/certifications_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/company_profile_setup_dialog.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experiences_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industries_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_base_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/products_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/services_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technologies_screen.dart';
import 'package:jva_projecttracker/services/certification_eligibility.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';
import 'package:jva_projecttracker/widgets/fade_slide_in.dart';
import 'package:jva_projecttracker/widgets/knowledge_summary_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/stat_card.dart';
import 'package:jva_projecttracker/widgets/stat_card_row.dart';

class _CiCategory {
  const _CiCategory({
    required this.icon,
    required this.title,
    required this.count,
    required this.recentlyUpdatedLabel,
    required this.relatedOpportunitiesLabel,
    required this.health,
    required this.healthLabel,
    required this.page,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final int count;
  final String recentlyUpdatedLabel;
  final String relatedOpportunitiesLabel;
  final KnowledgeHealth health;
  final String healthLabel;
  final Widget page;

  /// Entity-type identity color (see `AppEntityColors`) — what kind of
  /// thing this category is, independent of [health]/[healthLabel], which
  /// still carry this category's coverage status.
  final Color accentColor;

  /// A short, specific line for the "needs attention" strip — reuses labels
  /// already computed for this category instead of inventing new copy, so
  /// no new per-category strings are needed. Falls back to
  /// [recentlyUpdatedLabel] for categories (like Certifications) that don't
  /// carry a related-opportunities count.
  String get attentionSubtitle => relatedOpportunitiesLabel.isNotEmpty
      ? '$healthLabel \u00b7 $relatedOpportunitiesLabel'
      : '$healthLabel \u00b7 $recentlyUpdatedLabel';
}

_CiCategory _buildCategory<T>({
  required IconData icon,
  required String title,
  required KnowledgeEntitySummary<T> summary,
  required String Function(T) nameOf,
  required DateTime Function(T) updatedAtOf,
  required AppStrings strings,
  required Widget page,
  required Color accentColor,
}) {
  final mostRecent = summary.mostRecentlyUpdated;
  final recentlyUpdatedLabel = mostRecent == null
      ? strings.noKnowledgeItemsYetLabel
      : strings.recentlyUpdatedLabel(
          nameOf(mostRecent),
          DateFormat.yMMMd(
            strings.locale.languageCode,
          ).format(updatedAtOf(mostRecent)),
        );

  return _CiCategory(
    icon: icon,
    title: title,
    count: summary.count,
    recentlyUpdatedLabel: recentlyUpdatedLabel,
    relatedOpportunitiesLabel: strings.relatedOpportunitiesCountLabel(
      summary.relatedOpportunityCount,
    ),
    health: summary.health,
    healthLabel: strings.knowledgeHealthLabel(summary.health),
    page: page,
    accentColor: accentColor,
  );
}

/// Certifications don't fit `_buildCategory<T>`'s shape honestly: they
/// aren't referenced by Opportunities via any `certificationIds` field the
/// way every other Company Intelligence entity is (their relationship to
/// the pipeline is indirect, via the type-based eligibility gap engine —
/// see `certification_eligibility.dart`), so "opportunities referencing
/// this" has no real meaning here. Built by hand instead: health is
/// `noData` when nothing is recorded yet, `gap` when nothing currently
/// held is valid (all expired/revoked), `covered` once at least one
/// currently-valid certification exists. No `attention` tier — there's no
/// partial-coverage concept for a single company-wide credential set the
/// way there is for e.g. "how many opportunities reference this Capability."
_CiCategory _buildCertificationCategory({
  required AppStrings strings,
  required List<Certification> certifications,
}) {
  final now = DateTime.now();
  final validCount = certifications
      .where((c) => isCertificationCurrentlyValid(c, now: now))
      .length;

  final health = certifications.isEmpty
      ? KnowledgeHealth.noData
      : (validCount == 0 ? KnowledgeHealth.gap : KnowledgeHealth.covered);

  return _CiCategory(
    icon: Icons.verified_outlined,
    title: strings.certificationsTitle,
    count: certifications.length,
    recentlyUpdatedLabel: certifications.isEmpty
        ? strings.certificationsNoneHeldLabel
        : strings.certificationsActiveCountLabel(validCount),
    relatedOpportunitiesLabel: '',
    health: health,
    healthLabel: strings.knowledgeHealthLabel(health),
    page: const CertificationsScreen(),
    accentColor: AppEntityColors.certification,
  );
}

/// Lower number sorts first — [KnowledgeHealth.gap] (zero coverage) is a
/// stronger signal than [KnowledgeHealth.attention] (partial coverage), so
/// it leads the "needs attention" strip. [KnowledgeHealth.noData] and
/// [KnowledgeHealth.covered] never appear in that strip at all (see
/// `_needsAttention` below) — an entity type with nothing recorded yet is
/// already surfaced by the "set up company profile" banner, not a coverage
/// problem to chase.
int _attentionRank(KnowledgeHealth health) => switch (health) {
  KnowledgeHealth.gap => 0,
  KnowledgeHealth.attention => 1,
  KnowledgeHealth.noData => 2,
  KnowledgeHealth.covered => 2,
};

/// The Company Intelligence Knowledge Workspace — a prioritized operating
/// surface, not a flat report: categories with a real coverage problem
/// (`gap`/`attention`) surface first in their own strip, ranked by
/// severity, above the full category grid. Every signal here is derived
/// client-side from data already loaded elsewhere in the app — no new
/// reads. See `knowledge_health.dart` for how health is computed.
class CompanyIntelligenceScreen extends ConsumerWidget {
  const CompanyIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final overview = ref.watch(knowledgeGraphOverviewProvider);

    final categories = [
      _buildCategory<BusinessUnit>(
        icon: Icons.apartment_outlined,
        title: strings.businessUnitsTitle,
        summary: ref.watch(businessUnitKnowledgeSummaryProvider),
        nameOf: (b) => b.name,
        updatedAtOf: (b) => b.updatedAt,
        strings: strings,
        page: const BusinessUnitsScreen(),
        accentColor: AppEntityColors.businessUnit,
      ),
      _buildCategory<Product>(
        icon: Icons.inventory_2_outlined,
        title: strings.productsTitle,
        summary: ref.watch(productKnowledgeSummaryProvider),
        nameOf: (p) => p.name,
        updatedAtOf: (p) => p.updatedAt,
        strings: strings,
        page: const ProductsScreen(),
        accentColor: AppEntityColors.product,
      ),
      _buildCategory<ServiceModel>(
        icon: Icons.miscellaneous_services_outlined,
        title: strings.servicesTitle,
        summary: ref.watch(serviceKnowledgeSummaryProvider),
        nameOf: (s) => s.name,
        updatedAtOf: (s) => s.updatedAt,
        strings: strings,
        page: const ServicesScreen(),
        accentColor: AppEntityColors.service,
      ),
      _buildCategory<Capability>(
        icon: Icons.extension_outlined,
        title: strings.capabilitiesTitle,
        summary: ref.watch(capabilityKnowledgeSummaryProvider),
        nameOf: (c) => c.name,
        updatedAtOf: (c) => c.updatedAt,
        strings: strings,
        page: const CapabilitiesScreen(),
        accentColor: AppEntityColors.capability,
      ),
      _buildCategory<Technology>(
        icon: Icons.memory_outlined,
        title: strings.technologiesTitle,
        summary: ref.watch(technologyKnowledgeSummaryProvider),
        nameOf: (t) => t.name,
        updatedAtOf: (t) => t.updatedAt,
        strings: strings,
        page: const TechnologiesScreen(),
        accentColor: AppEntityColors.technology,
      ),
      _buildCategory<Industry>(
        icon: Icons.factory_outlined,
        title: strings.industriesTitle,
        summary: ref.watch(industryKnowledgeSummaryProvider),
        nameOf: (i) => i.name,
        updatedAtOf: (i) => i.updatedAt,
        strings: strings,
        page: const IndustriesScreen(),
        accentColor: AppEntityColors.industry,
      ),
      _buildCategory<Experience>(
        icon: Icons.military_tech_outlined,
        title: strings.experiencesTitle,
        summary: ref.watch(experienceKnowledgeSummaryProvider),
        nameOf: (e) => e.title,
        updatedAtOf: (e) => e.updatedAt,
        strings: strings,
        page: const ExperiencesScreen(),
        accentColor: AppEntityColors.experience,
      ),
      _buildCategory<KnowledgeArticle>(
        icon: Icons.menu_book_outlined,
        title: strings.knowledgeBaseTitle,
        summary: ref.watch(knowledgeArticleKnowledgeSummaryProvider),
        nameOf: (k) => k.title,
        updatedAtOf: (k) => k.updatedAt,
        strings: strings,
        page: const KnowledgeBaseScreen(),
        accentColor: AppEntityColors.knowledgeBase,
      ),
      _buildCertificationCategory(
        strings: strings,
        certifications:
            ref.watch(certificationsStreamProvider).value ?? const [],
      ),
    ];

    // Deliberately NOT `overview.totalEntities == 0` — that sums across all
    // 8 types including Experiences/Knowledge Articles, which are commonly
    // non-empty (populated via project promotion) long before the graph
    // "spine" (Business Units/Products/Services/Capabilities — the 4 types
    // `showCompanyProfileSetupDialog` seeds) has anything in it. Checking
    // the sum meant this banner could never show once a single Experience
    // existed, even with every other section still genuinely empty.
    final spineEmpty = categories
        .take(4) // Business Units, Products, Services, Capabilities
        .every((c) => c.count == 0);

    // Only genuine coverage problems belong here — noData/covered categories
    // stay out (see `_attentionRank`'s doc comment) so this strip doesn't
    // turn into a second, noisier copy of the full grid below.
    final needsAttention =
        categories
            .where(
              (c) =>
                  c.health == KnowledgeHealth.gap ||
                  c.health == KnowledgeHealth.attention,
            )
            .toList()
          ..sort(
            (a, b) =>
                _attentionRank(a.health).compareTo(_attentionRank(b.health)),
          );

    // The whole screen is one CustomScrollView (fixed header content as
    // SliverToBoxAdapters, the category grid as a SliverGrid/SliverList at
    // the end) rather than a Column with a single Expanded(AdaptiveListGrid)
    // scroll region — that arrangement broke on short viewports (mobile,
    // or any window short enough that the fixed header content plus the
    // grid's minimum height exceeded what was available), producing bottom
    // overflow and, once Expanded's computed height went negative, "Unexpected
    // null value" render exceptions. Making everything scroll together means
    // there is no fixed-vs-scrollable height budget to blow.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTileWidth = 260.0;
            const tileHeight = 232.0;
            final crossAxisCount = (constraints.maxWidth / minTileWidth)
                .floor()
                .clamp(1, 4);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      icon: Icons.insights_outlined,
                      title: strings.companyIntelligenceTitle,
                      subtitle: strings.companyIntelligenceSubtitle,
                      accentColor: AppStatusColors.technology,
                    ),
                  ),
                ),
                if (spineEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final message = Text(
                                strings.setUpCompanyProfileEmptyStateMessage,
                                style: Theme.of(context).textTheme.bodyMedium,
                              );
                              final button = FilledButton(
                                onPressed: () =>
                                    showCompanyProfileSetupDialog(context),
                                child: Text(strings.setUpCompanyProfileButton),
                              );
                              if (constraints.maxWidth <
                                  AppBreakpoints.compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    message,
                                    const SizedBox(height: AppSpacing.md),
                                    button,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: message),
                                  const SizedBox(width: AppSpacing.md),
                                  button,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: StatCardRow(
                        children: [
                          // Gaps lead — it's the one number here that's
                          // actually actionable; total/recently-updated are
                          // context, not a call to do anything.
                          StatCard(
                            icon: Icons.warning_amber_outlined,
                            label: strings.capabilityGapsLabel,
                            value: '${overview.capabilityGapCount}',
                          ),
                          StatCard(
                            icon: Icons.hub_outlined,
                            label: strings.totalKnowledgeItemsLabel,
                            value: '${overview.totalEntities}',
                          ),
                          StatCard(
                            icon: Icons.update_outlined,
                            label: strings.updatedRecentlyLabel,
                            value: '${overview.recentlyUpdatedCount}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (needsAttention.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: strings.needsAttentionSectionTitle,
                            accentColor: AppStatusColors.danger,
                          ),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                // Capped, not unbounded — `needsAttention`
                                // is already sorted by severity, so the top
                                // items shown are the most actionable ones;
                                // capping keeps this strip a "handful of
                                // items", never a second copy of the full
                                // grid below.
                                for (final c in needsAttention.take(3))
                                  ListTile(
                                    leading: Icon(
                                      c.icon,
                                      color: c.health == KnowledgeHealth.gap
                                          ? AppStatusColors.danger
                                          : AppStatusColors.warning,
                                    ),
                                    title: Text(c.title),
                                    subtitle: Text(c.attentionSubtitle),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => pushSlideFade(context, c.page),
                                  ),
                                if (needsAttention.length > 3)
                                  ListTile(
                                    title: Text(
                                      strings.moreItemsNeedAttentionLabel(
                                        needsAttention.length - 3,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: SectionHeader(
                      title: strings.allCompanyKnowledgeSectionTitle,
                    ),
                  ),
                ),
                if (crossAxisCount == 1)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => FadeSlideIn(
                        index: i,
                        child: _buildCategoryCard(context, categories[i]),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: minTileWidth,
                        mainAxisExtent: tileHeight,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => FadeSlideIn(
                          index: i,
                          child: _buildCategoryCard(context, categories[i]),
                        ),
                        childCount: categories.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, _CiCategory category) {
    return KnowledgeSummaryCard(
      icon: category.icon,
      title: category.title,
      count: category.count,
      recentlyUpdatedLabel: category.recentlyUpdatedLabel,
      relatedOpportunitiesLabel: category.relatedOpportunitiesLabel,
      health: category.health,
      healthLabel: category.healthLabel,
      accentColor: category.accentColor,
      onTap: () => pushSlideFade(context, category.page),
    );
  }
}
