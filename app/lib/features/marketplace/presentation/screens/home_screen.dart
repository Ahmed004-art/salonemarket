import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_cards.dart';
import '../../../../core/widgets/salone_motion.dart';
import '../../../../core/widgets/salone_states.dart';
import '../../../../core/widgets/salone_text_field.dart';
import '../../../auth/presentation/controllers/auth_notifier.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../controllers/marketplace_notifier.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/marketplace_app_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/promotional_carousel.dart';

/// Customer Home Screen featuring personalized greeting, categories, promotions,
/// and curated product grids.
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
      if (mounted) {
        context.read<MarketplaceNotifier>().loadHome();
      }
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentBottomNavIndex = index);
    switch (index) {
      case 0:
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
    final auth = context.watch<AuthNotifier>();
    final cartCount = context.watch<CartNotifier>().itemCount;
    final isLoading = marketplace.isHomeLoading;
    final categories = marketplace.categories;
    final featured = marketplace.featuredProducts;
    final popular = marketplace.popularProducts;

    final firstName = auth.userDisplayName.split(' ').first;
    final greeting = auth.isAuthenticated && firstName.isNotEmpty
        ? 'Hello, $firstName'
        : 'Welcome to SaloneMarket';

    final scrollBody = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personalized Greeting & Delivery Location Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: SaloneColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: SaloneColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Delivering across Freetown & Sierra Leone',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: SaloneColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar Trigger
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SaloneSearchBar(
              readOnly: true,
              hint: 'Search electronics, fashion, groceries...',
              onTap: () => context.push(Routes.search),
              trailing: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SaloneColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: SaloneColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Promotional Carousel (real data)
          const PromotionalCarousel(),
          const SizedBox(height: AppSpacing.lg),

          // Categories
          if (categories.isNotEmpty) ...[
            SaloneSectionHeader(
              title: 'Shop by Category',
              actionLabel: 'See All',
              onAction: () => context.push(Routes.categories),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
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

          // Featured Products
          if (isLoading && featured.isEmpty) ...[
            const SaloneSectionHeader(
              title: 'Featured Products',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            const SaloneProductGridSkeleton(itemCount: 4),
            const SizedBox(height: AppSpacing.lg),
          ] else if (featured.isNotEmpty) ...[
            SaloneSectionHeader(
              title: 'Featured Products',
              subtitle: 'Handpicked from verified local stores',
              actionLabel: 'Browse All',
              onAction: () => context.push(Routes.categories),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildProductGrid(featured.take(4).toList()),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Popular / Trending Products
          if (popular.isNotEmpty) ...[
            SaloneSectionHeader(
              title: 'Trending in Sierra Leone',
              actionLabel: 'See More',
              onAction: () => context.push(Routes.categories),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildProductGrid(popular.take(4).toList()),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Empty State
          if (!isLoading && featured.isEmpty && popular.isEmpty)
            SaloneEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Explore SaloneMarket',
              message:
                  'Connect with verified Sierra Leonean merchants, artisans, and grocers across the country.',
              actionLabel: 'Explore Categories',
              onAction: () => context.push(Routes.categories),
            ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: SaloneColors.background,
      appBar: const MarketplaceAppBar(),
      body: kIsWeb
          ? scrollBody
          : RefreshIndicator(
              color: SaloneColors.secondary,
              backgroundColor: SaloneColors.surface,
              onRefresh: () => marketplace.loadHome(forceRefresh: true),
              child: scrollBody,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomNavIndex,
        onDestinationSelected: _onBottomNavTapped,
        backgroundColor: SaloneColors.surface,
        indicatorColor: SaloneColors.cream,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: SaloneColors.primary),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon:
                Icon(Icons.grid_view_rounded, color: SaloneColors.primary),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: SaloneColors.gold,
              textColor: SaloneColors.textPrimary,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: SaloneColors.gold,
              textColor: SaloneColors.textPrimary,
              child: const Icon(Icons.shopping_bag_rounded,
                  color: SaloneColors.primary),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: SaloneColors.primary),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: SaloneColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return SaloneFadeIn(
            delayMs: index * 40,
            child: ProductCard(product: products[index]),
          );
        },
      ),
    );
  }
}
