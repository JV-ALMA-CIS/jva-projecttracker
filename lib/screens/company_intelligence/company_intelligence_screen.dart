import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_units_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/capabilities/capabilities_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/company_profile_setup_dialog.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experiences_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industries_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_base_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/products_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/services/services_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technologies_screen.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/knowledge_summary_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
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
  });

  final IconData icon;
  final String title;
  final int count;
  final String recentlyUpdatedLabel;
  final String relatedOpportunitiesLabel;
  final KnowledgeHealth health;
  final String healthLabel;
  final Widget page;
}

_CiCategory _buildCategory<T>({
  required IconData icon,
  required String title,
  required KnowledgeEntitySummary<T> summary,
  required String Function(T) nameOf,
  required DateTime Function(T) updatedAtOf,
  required AppStrings strings,
  required Widget page,
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
  );
}

/// The Company Intelligence Knowledge Workspace — an executive summary plus
/// one rich card per entity in the Company Intelligence Graph, each showing
/// its count, most-recently-updated item, how many opportunities reference
/// it, and an AI-derived coverage health signal. Replaces the previous hub,
/// which showed only a bare count per entity with no sense of how connected
/// the knowledge graph is to the actual opportunity pipeline. See
/// `knowledge_health.dart` for how every signal here is derived — purely
/// client-side from data already loaded elsewhere in the app, no new reads.
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
      ),
      _buildCategory<Product>(
        icon: Icons.inventory_2_outlined,
        title: strings.productsTitle,
        summary: ref.watch(productKnowledgeSummaryProvider),
        nameOf: (p) => p.name,
        updatedAtOf: (p) => p.updatedAt,
        strings: strings,
        page: const ProductsScreen(),
      ),
      _buildCategory<ServiceModel>(
        icon: Icons.miscellaneous_services_outlined,
        title: strings.servicesTitle,
        summary: ref.watch(serviceKnowledgeSummaryProvider),
        nameOf: (s) => s.name,
        updatedAtOf: (s) => s.updatedAt,
        strings: strings,
        page: const ServicesScreen(),
      ),
      _buildCategory<Capability>(
        icon: Icons.extension_outlined,
        title: strings.capabilitiesTitle,
        summary: ref.watch(capabilityKnowledgeSummaryProvider),
        nameOf: (c) => c.name,
        updatedAtOf: (c) => c.updatedAt,
        strings: strings,
        page: const CapabilitiesScreen(),
      ),
      _buildCategory<Technology>(
        icon: Icons.memory_outlined,
        title: strings.technologiesTitle,
        summary: ref.watch(technologyKnowledgeSummaryProvider),
        nameOf: (t) => t.name,
        updatedAtOf: (t) => t.updatedAt,
        strings: strings,
        page: const TechnologiesScreen(),
      ),
      _buildCategory<Industry>(
        icon: Icons.factory_outlined,
        title: strings.industriesTitle,
        summary: ref.watch(industryKnowledgeSummaryProvider),
        nameOf: (i) => i.name,
        updatedAtOf: (i) => i.updatedAt,
        strings: strings,
        page: const IndustriesScreen(),
      ),
      _buildCategory<Experience>(
        icon: Icons.military_tech_outlined,
        title: strings.experiencesTitle,
        summary: ref.watch(experienceKnowledgeSummaryProvider),
        nameOf: (e) => e.title,
        updatedAtOf: (e) => e.updatedAt,
        strings: strings,
        page: const ExperiencesScreen(),
      ),
      _buildCategory<KnowledgeArticle>(
        icon: Icons.menu_book_outlined,
        title: strings.knowledgeBaseTitle,
        summary: ref.watch(knowledgeArticleKnowledgeSummaryProvider),
        nameOf: (k) => k.title,
        updatedAtOf: (k) => k.updatedAt,
        strings: strings,
        page: const KnowledgeBaseScreen(),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
              ),
            ),
            if (spineEmpty)
              Padding(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.setUpCompanyProfileEmptyStateMessage,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        FilledButton(
                          onPressed: () =>
                              showCompanyProfileSetupDialog(context),
                          child: Text(strings.setUpCompanyProfileButton),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: StatCardRow(
                  children: [
                    StatCard(
                      icon: Icons.hub_outlined,
                      label: strings.totalKnowledgeItemsLabel,
                      value: '${overview.totalEntities}',
                    ),
                    StatCard(
                      icon: Icons.warning_amber_outlined,
                      label: strings.capabilityGapsLabel,
                      value: '${overview.capabilityGapCount}',
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
            Expanded(
              child: AdaptiveListGrid<_CiCategory>(
                items: categories,
                minTileWidth: 260,
                tileHeight: 232,
                itemBuilder: (context, category) => KnowledgeSummaryCard(
                  icon: category.icon,
                  title: category.title,
                  count: category.count,
                  recentlyUpdatedLabel: category.recentlyUpdatedLabel,
                  relatedOpportunitiesLabel: category.relatedOpportunitiesLabel,
                  health: category.health,
                  healthLabel: category.healthLabel,
                  onTap: () => pushSlideFade(context, category.page),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
