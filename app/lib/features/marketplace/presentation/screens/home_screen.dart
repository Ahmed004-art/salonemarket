import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/marketplace_notifier.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/marketplace_app_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/promotional_carousel.dart';

/// Customer Home Screen featuring marketplace highlights, categories, and curated products.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceNotifier>().loadHome();
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentBottomNavIndex = index);
    switch (index) {
      case 0:
        // Already on Home
        break;
      case 1:
        context.push(Routes.categories);
        break;
      case 2:
        context.push(Routes.cart);
        break;
      case 3:
        context.push(Routes.orders);
        break;
      case 4:
        context.push(Routes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<MarketplaceNotifier>();
    final isLoading = marketplace.isHomeLoading;
    final categories = marketplace.categories;
    final featured = marketplace.featuredProducts;
    final popular = marketplace.popularProducts;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: const MarketplaceAppBar(),
      body: RefreshIndicator(
        color: SaloneMarketTheme.accent,
        backgroundColor: SaloneMarketTheme.surface,
        onRefresh: () => marketplace.loadHome(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // Search Trigger Bar
              _buildSearchBarTrigger(context),
              const SizedBox(height: AppSpacing.md),

              // Hero Promotional Banner
              const PromotionalCarousel(),
              const SizedBox(height: AppSpacing.lg),

              // Categories Section
              if (categories.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Shop by Category',
                  actionLabel: 'See All',
                  onAction: () => context.push(Routes.categories),
                ),
                const SizedBox(height: AppSpacing.xs),
                CategoryChipBar(
                  categories: categories,
                  selectedCategoryId: null,
                  onCategorySelected: (catId) {
                    if (catId != null) {
                      context.push('/categories/$catId');
                    } else {
                      context.push(Routes.categories);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Featured Products Section
              if (isLoading && featured.isEmpty)
                _buildLoadingSection('Featured Products')
              else if (featured.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Featured Products',
                  actionLabel: 'Browse All',
                  onAction: () => context.push(Routes.categories),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildProductGrid(featured.take(4).toList()),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Popular / Trending Section
              if (popular.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Trending in Sierra Leone',
                  actionLabel: 'See More',
                  onAction: () => context.push(Routes.categories),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildProductGrid(popular.take(4).toList()),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Unconfigured / Empty Marketplace State
              if (!isLoading && featured.isEmpty && popular.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: EmptyStateView(
                    icon: Icons.storefront_outlined,
                    title: 'Welcome to SaloneMarket',
                    message:
                        'Connect with authentic Sierra Leonean merchants, artisans, and vendors across the country.',
                    actionLabel: 'Explore Categories',
                    onAction: () => context.push(Routes.categories),
                  ),
                ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: _onBottomNavTapped,
        backgroundColor: SaloneMarketTheme.surface,
        selectedItemColor: SaloneMarketTheme.accent,
        unselectedItemColor: SaloneMarketTheme.muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarTrigger(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: InkWell(
        onTap: () => context.push(Routes.search),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: SaloneMarketTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SaloneMarketTheme.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 20,
                color: SaloneMarketTheme.muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Search electronics, fashion, food...',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.tune,
                  size: 16,
                  color: SaloneMarketTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SaloneMarketTheme.primary,
              letterSpacing: -0.3,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: SaloneMarketTheme.accent,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SaloneMarketTheme.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }

  Widget _buildLoadingSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SaloneMarketTheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                SaloneMarketTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
