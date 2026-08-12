import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/product_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/product_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ProductStatus status) => switch (status) {
  ProductStatus.active => AppStatusColors.success,
  ProductStatus.archived => Colors.grey,
};

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key, this.businessUnitId, this.businessUnitName});

  final String? businessUnitId;
  final String? businessUnitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final productsAsync = businessUnitId == null
        ? ref.watch(productsStreamProvider)
        : ref.watch(productsByBusinessUnitProvider(businessUnitId!));
    final title = businessUnitName != null
        ? '$businessUnitName · ${strings.productsTitle}'
        : strings.productsTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushSlideFade(
          context,
          ProductFormScreen(businessUnitId: businessUnitId),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: productsAsync.when(
          data: (products) {
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
                    icon: Icons.inventory_2_outlined,
                    title: title,
                    subtitle: strings.productsSubtitle,
                  ),
                ),
                Expanded(
                  child: products.isEmpty
                      ? EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: strings.noProductsYet,
                          body: strings.productFormHintMessage,
                          action: FilledButton.icon(
                            onPressed: () => pushSlideFade(
                              context,
                              ProductFormScreen(businessUnitId: businessUnitId),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(strings.newProductTitle),
                          ),
                        )
                      : AdaptiveListGrid(
                          items: products,
                          itemBuilder: (context, product) => EntityCard(
                            title: product.name,
                            subtitle: product.summary.isNotEmpty
                                ? product.summary
                                : product.description,
                            statusBadge: StatusBadge(
                              label: product.status.label,
                              color: _statusColor(product.status),
                            ),
                            metaChips: [
                              if (product.capabilityIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${product.capabilityIds.length} capabilities',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (product.industryIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${product.industryIds.length} industries',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (product.technologyIds.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${product.technologyIds.length} technologies',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (product.storeUrl?.isNotEmpty ?? false)
                                Chip(
                                  avatar: const Icon(
                                    Icons.open_in_new,
                                    size: 14,
                                  ),
                                  label: Text(strings.openStoreLinkButton),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                            onTap: () => pushSlideFade(
                              context,
                              ProductWorkspaceScreen(productId: product.id),
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
