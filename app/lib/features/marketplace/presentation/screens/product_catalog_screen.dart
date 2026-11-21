import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/marketplace_notifier.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/marketplace_app_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filter_sheet.dart';

/// Product Catalog & Search screen supporting filtering, searching, and sorting.
class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({
    super.key,
    this.initialCategoryId,
    this.initialQuery,
  });

  final String? initialCategoryId;
  final String? initialQuery;

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = context.read<MarketplaceNotifier>();
      // Ensure categories are loaded for filter bar
      if (notifier.categories.isEmpty) {
        notifier.loadHome();
      }
      notifier.loadCatalog(
        categoryId: widget.initialCategoryId,
        search: widget.initialQuery,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSortSheet(BuildContext context) {
    final notifier = context.read<MarketplaceNotifier>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductFilterSheet(
        selectedSort: notifier.sortBy,
        onSortSelected: (sort) => notifier.setSortBy(sort),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MarketplaceNotifier>();
    final products = notifier.catalogProducts;
    final categories = notifier.categories;
    final isLoading = notifier.isCatalogLoading;
    final selectedCategoryId = notifier.selectedCategoryId;
    final error = notifier.catalogError;

    // Find category title if active
    final activeCategory = categories.cast<dynamic>().firstWhere(
          (c) => c.id == selectedCategoryId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: MarketplaceAppBar(
        showBack: true,
        title: activeCategory != null ? activeCategory.name : 'Product Catalog',
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: SaloneMarketTheme.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SaloneMarketTheme.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (query) => notifier.setSearchQuery(query),
                      decoration: InputDecoration(
                        hintText: 'Search products or vendors...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: SaloneMarketTheme.muted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: SaloneMarketTheme.muted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: () => _openSortSheet(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SaloneMarketTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort,
                          size: 18,
                          color: SaloneMarketTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sort',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SaloneMarketTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Category Filter Pills
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            CategoryChipBar(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onCategorySelected: (catId) => notifier.selectCategory(catId),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),

          // Results summary bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLoading
                      ? 'Loading items...'
                      : '${products.length} products available',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                if (selectedCategoryId != null ||
                    _searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      notifier.clearFilters();
                    },
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SaloneMarketTheme.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Product Grid or Empty/Loading States
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        SaloneMarketTheme.accent,
                      ),
                    ),
                  )
                : error != null
                    ? EmptyStateView(
                        icon: Icons.error_outline,
                        title: 'Unable to Load Products',
                        message: error,
                        actionLabel: 'Retry',
                        onAction: () => notifier.loadCatalog(),
                      )
                    : products.isEmpty
                        ? EmptyStateView(
                            title: 'No Products Found',
                            message:
                                'Try clearing your search terms or selecting a different category.',
                            actionLabel: 'Browse All Products',
                            onAction: () {
                              _searchController.clear();
                              notifier.clearFilters();
                            },
                          )
                        : RefreshIndicator(
                            color: SaloneMarketTheme.accent,
                            onRefresh: () => notifier.loadCatalog(),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                return ProductCard(product: products[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
