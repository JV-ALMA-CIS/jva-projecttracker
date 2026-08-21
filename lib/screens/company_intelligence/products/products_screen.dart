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
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ProductStatus status) => switch (status) {
  ProductStatus.active => AppStatusColors.success,
  ProductStatus.archived => AppStatusColors.neutral,
};

/// Search/filter parity fix on top of the `heroTag: null` fix — see
/// `BusinessUnitsScreen`'s doc comment. [businessUnitId]/[businessUnitName]
/// are unchanged from before: when set (pushed from a Business Unit
/// workspace), the stream itself is already scoped server-side, so the
/// local search/filter here layers on top of that scope rather than
/// competing with it.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.businessUnitId, this.businessUnitName});

  final String? businessUnitId;
  final String? businessUnitName;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ProductStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> products) {
    final query = _query.trim().toLowerCase();
    return products.where((p) {
      if (_statusFilter != null && p.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.summary.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final productsAsync = widget.businessUnitId == null
        ? ref.watch(productsStreamProvider)
        : ref.watch(productsByBusinessUnitProvider(widget.businessUnitId!));
    final title = widget.businessUnitName != null
        ? '${widget.businessUnitName} · ${strings.productsTitle}'
        : strings.productsTitle;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => pushSlideFade(
          context,
          ProductFormScreen(businessUnitId: widget.businessUnitId),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
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
                      icon: Icons.inventory_2_outlined,
                      title: title,
                      subtitle: strings.productsSubtitle,
                      accentColor: AppEntityColors.product,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: strings.noProductsYet,
                      body: strings.productFormHintMessage,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          ProductFormScreen(
                            businessUnitId: widget.businessUnitId,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newProductTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final filtered = _applyFilters(products);

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
                    icon: Icons.inventory_2_outlined,
                    title: title,
                    subtitle: strings.productsSubtitle,
                    accentColor: AppEntityColors.product,
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
                    hintText: strings.searchProductsHint,
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
                      for (final s in ProductStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statusFilter == s,
                          onSelected: (selected) => setState(
                            () => _statusFilter = selected ? s : null,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noProductsMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, product) => EntityCard(
                            title: product.name,
                            subtitle: product.summary.isNotEmpty
                                ? product.summary
                                : product.description,
                            statusBadge: StatusBadge(
                              label: product.status.label,
                              color: _statusColor(product.status),
                            ),
                            accentColor: AppEntityColors.product,
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
