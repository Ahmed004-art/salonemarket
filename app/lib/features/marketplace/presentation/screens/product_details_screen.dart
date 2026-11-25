import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../../../wishlist/presentation/controllers/wishlist_notifier.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/marketplace_app_bar.dart';
import '../widgets/product_image_gallery.dart';
import '../widgets/product_review_dialog.dart';
import '../widgets/quantity_selector.dart';

/// Screen displaying complete details for a single product with cart interaction.
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _repository = MarketplaceRepository();
  Product? _product;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getProductById(widget.productId);

    if (!mounted) return;

    if (result is MarketplaceSuccess<Product>) {
      setState(() {
        _product = result.value;
        _isLoading = false;
      });
    } else if (result is MarketplaceFailure<Product>) {
      setState(() {
        _errorMessage = result.message;
        _isLoading = false;
      });
    }
  }

  void _handleAddToCart(Product product) {
    if (!product.isInStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This product is currently out of stock.',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    final added = context
        .read<CartNotifier>()
        .addItem(product, quantity: _selectedQuantity);

    if (added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $_selectedQuantity x ${product.name} to cart',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          duration: const Duration(seconds: 3),
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
            'Cannot add $_selectedQuantity units. Available inventory limit reached.',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SaloneMarketTheme.background,
        appBar: MarketplaceAppBar(showBack: true),
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              SaloneMarketTheme.accent,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null || _product == null) {
      return Scaffold(
        backgroundColor: SaloneMarketTheme.background,
        appBar: const MarketplaceAppBar(showBack: true),
        body: EmptyStateView(
          icon: Icons.error_outline,
          title: 'Product Unavailable',
          message: _errorMessage ??
              'This product could not be found or is no longer active.',
          actionLabel: 'Return to Catalog',
          onAction: () => context.go(Routes.categories),
        ),
      );
    }

    final product = _product!;
    final totalPrice = product.price * _selectedQuantity;
    final formattedTotal = totalPrice == totalPrice.roundToDouble()
        ? 'SLE ${totalPrice.toInt()}'
        : 'SLE ${totalPrice.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: MarketplaceAppBar(
        showBack: true,
        title: product.categoryName ?? AppConstants.appName,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            ProductImageGallery(images: product.images),

            // Content Container
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock Status & Category badge row
                  Row(
                    children: [
                      _buildStockBadge(product),
                      const SizedBox(width: AppSpacing.sm),
                      if (product.categoryName != null)
                        Text(
                          product.categoryName!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SaloneMarketTheme.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Product Title & Wishlist Toggle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: SaloneMarketTheme.primary,
                            height: 1.25,
                          ),
                        ),
                      ),
                      Consumer<WishlistNotifier>(
                        builder: (context, wishlist, _) {
                          final isFav = wishlist.isProductWishlisted(product.id);
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : SaloneMarketTheme.muted,
                            ),
                            tooltip: isFav
                                ? 'Remove from wishlist'
                                : 'Add to wishlist',
                            onPressed: () {
                              wishlist.toggleWishlist(product.id);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Price block
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        product.formattedPrice,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                      if (product.compareAtPrice != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          product.formattedCompareAtPrice!,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: SaloneMarketTheme.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SaloneMarketTheme.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${product.discountPercentage}% OFF',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: SaloneMarketTheme.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Vendor Information Card
                  if (product.vendor != null) _buildVendorCard(product.vendor!),
                  const SizedBox(height: AppSpacing.lg),

                  // Description Section
                  Text(
                    'Product Description',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SaloneMarketTheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    product.description != null && product.description!.isNotEmpty
                        ? product.description!
                        : 'No description provided by the merchant for this product.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: SaloneMarketTheme.muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Customer Reviews & Ratings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verified Reviews',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Write Review'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => ProductReviewDialog(
                              productId: product.id,
                              productName: product.name,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        product.ratingAvg > 0
                            ? product.ratingAvg.toStringAsFixed(1)
                            : 'No ratings yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (product.ratingCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${product.ratingCount} verified ratings)',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: SaloneMarketTheme.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),

      // Fixed Bottom Sticky Bar for Quantity Selection and Add to Cart
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              QuantitySelector(
                quantity: _selectedQuantity,
                maxQuantity: product.trackInventory && product.stockQuantity > 0
                    ? product.stockQuantity
                    : 99,
                onChanged: (qty) => setState(() => _selectedQuantity = qty),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: product.isInStock
                        ? () => _handleAddToCart(product)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaloneMarketTheme.accent,
                      foregroundColor: SaloneMarketTheme.onAccent,
                      disabledBackgroundColor:
                          SaloneMarketTheme.muted.withValues(alpha: 0.3),
                      disabledForegroundColor: SaloneMarketTheme.muted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            product.isInStock
                                ? 'Add to Cart • $formattedTotal'
                                : 'Out of Stock',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: SaloneMarketTheme.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(Product product) {
    Color badgeColor;
    String label;

    if (!product.isInStock) {
      badgeColor = SaloneMarketTheme.error;
      label = 'Out of Stock';
    } else if (product.isLowStock) {
      badgeColor = SaloneMarketTheme.accent;
      label = 'Only ${product.stockQuantity} left';
    } else {
      badgeColor = SaloneMarketTheme.success;
      label = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildVendorCard(dynamic vendor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SaloneMarketTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SaloneMarketTheme.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Icon(
                Icons.storefront,
                color: SaloneMarketTheme.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vendor.shopName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: SaloneMarketTheme.accent,
                    ),
                  ],
                ),
                Text(
                  vendor.location ?? 'Freetown, Sierra Leone',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
