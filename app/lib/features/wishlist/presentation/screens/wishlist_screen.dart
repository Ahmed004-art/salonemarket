import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../controllers/wishlist_notifier.dart';

/// Screen displaying the customer's saved favorite products with quick add-to-cart.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistNotifier>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistNotifier>();
    final items = wishlist.items;
    final isLoading = wishlist.isLoading;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'My Wishlist',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => wishlist.loadWishlist(),
              color: SaloneMarketTheme.primary,
              child: items.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = item.product;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: SaloneMarketTheme.border),
                          ),
                          color: SaloneMarketTheme.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              context.push(
                                Routes.productDetail.replaceFirst(':productId', product.id),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: product.imageUrl != null &&
                                              product.imageUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: product.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.image,
                                                    color: Colors.grey),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.image,
                                                  color: Colors.grey),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          product.formattedPrice,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: SaloneMarketTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          product.isInStock
                                              ? 'In Stock'
                                              : 'Out of Stock',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            color: product.isInStock
                                                ? Colors.green.shade700
                                                : SaloneMarketTheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Actions: Add to Cart & Remove
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.favorite,
                                            color: Colors.red),
                                        onPressed: () {
                                          wishlist.toggleWishlist(product.id);
                                        },
                                        tooltip: 'Remove from wishlist',
                                      ),
                                      if (product.isInStock)
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_shopping_cart,
                                              color: SaloneMarketTheme.primary),
                                          onPressed: () {
                                            context
                                                .read<CartNotifier>()
                                                .addItem(product);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Added ${product.name} to cart'),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          tooltip: 'Add to cart',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border,
              size: 64,
              color: SaloneMarketTheme.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your wishlist is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Explore products and tap the heart icon to save items for later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Discover Products'),
            ),
          ],
        ),
      ),
    );
  }
}
