import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../../data/models/product_model.dart';

/// Standard product display card conforming to SaloneMarket design rules.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
  });

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/products/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: SaloneMarketTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SaloneMarketTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: product.primaryImageUrl != null &&
                              product.primaryImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ColoredBox(
                                color: SaloneMarketTheme.background,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        SaloneMarketTheme.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildImageFallback(),
                            )
                          : _buildImageFallback(),
                    ),
                  ),

                  // Sale badge
                  if (product.isOnSale)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SaloneMarketTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: SaloneMarketTheme.onAccent,
                          ),
                        ),
                      ),
                    ),

                  // Low stock badge
                  if (product.isLowStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SaloneMarketTheme.error.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Only ${product.stockQuantity} left',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Details
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vendor name
                        if (product.vendor != null)
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.vendor!.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: SaloneMarketTheme.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: SaloneMarketTheme.accent,
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),

                        // Title
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SaloneMarketTheme.primary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),

                    // Price and Add button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.compareAtPrice != null)
                                Text(
                                  product.formattedCompareAtPrice!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                    color: SaloneMarketTheme.muted,
                                  ),
                                ),
                              Text(
                                product.formattedPrice,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: SaloneMarketTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildQuickAddButton(context),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return ColoredBox(
      color: SaloneMarketTheme.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: SaloneMarketTheme.muted.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context) {
    if (!product.isInStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.muted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Out of stock',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: SaloneMarketTheme.muted,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        final added = context.read<CartNotifier>().addItem(product);
        if (added) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${product.name} to cart',
                style: GoogleFonts.dmSans(fontSize: 13),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: SaloneMarketTheme.primary,
              action: SnackBarAction(
                label: 'View Cart',
                textColor: SaloneMarketTheme.accent,
                onPressed: () => context.push(Routes.cart),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot add more of this item (Stock ceiling reached)',
                style: GoogleFonts.dmSans(fontSize: 13),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: SaloneMarketTheme.error,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.add_shopping_cart,
          size: 16,
          color: SaloneMarketTheme.onAccent,
        ),
      ),
    );
  }
}
