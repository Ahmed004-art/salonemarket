import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_motion.dart';
import '../../../../core/widgets/salone_states.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../../data/models/product_model.dart';

/// Standard product display card with press feedback, Hero image, and quick-add.
class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
  });

  final Product product;
  final bool compact;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final reduce = SaloneMotion.reduceMotion(context);

    return GestureDetector(
      onTapDown: reduce ? null : (_) => setState(() => _pressed = true),
      onTapUp: reduce ? null : (_) => setState(() => _pressed = false),
      onTapCancel: reduce ? null : () => setState(() => _pressed = false),
      onTap: () => context.push('/products/${product.id}'),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: SaloneMotion.fast,
        curve: SaloneMotion.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: SaloneColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: SaloneColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.large - 1),
                      ),
                      child: Hero(
                        tag: 'product-${product.id}',
                        child: Container(
                          color: SaloneColors.cream.withValues(alpha: 0.45),
                          width: double.infinity,
                          height: double.infinity,
                          child: product.primaryImageUrl != null &&
                                  product.primaryImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.primaryImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const SaloneShimmerBox(
                                    height: double.infinity,
                                    radius: 0,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      _buildImageFallback(),
                                )
                              : _buildImageFallback(),
                        ),
                      ),
                    ),
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: SaloneColors.gold,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(
                            '-${product.discountPercentage}%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: SaloneColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
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
                            color: SaloneColors.error.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(
                            'Only ${product.stockQuantity} left',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.vendor != null)
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    product.vendor!.shopName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: SaloneColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: SaloneColors.secondary,
                                ),
                              ],
                            ),
                          const SizedBox(height: 3),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: SaloneColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
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
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                      color: SaloneColors.textSecondary,
                                    ),
                                  ),
                                Text(
                                  product.formattedPrice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: SaloneColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildQuickAddButton(context, product),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return ColoredBox(
      color: SaloneColors.cream.withValues(alpha: 0.6),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: SaloneColors.textSecondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context, Product product) {
    if (!product.isInStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: SaloneColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Text(
          'Sold out',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: SaloneColors.textSecondary,
          ),
        ),
      );
    }

    return Material(
      color: SaloneColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: () {
          final added = context.read<CartNotifier>().addItem(product);
          if (added) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Added ${product.name} to cart'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: SaloneColors.primary,
                  action: SnackBarAction(
                    label: 'View Cart',
                    textColor: SaloneColors.gold,
                    onPressed: () => context.push(Routes.cart),
                  ),
                ),
              );
          } else {
            SaloneToast.show(
              context,
              'Cannot add more of this item (Stock ceiling reached)',
              isError: true,
            );
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(
            Icons.add_shopping_cart_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
