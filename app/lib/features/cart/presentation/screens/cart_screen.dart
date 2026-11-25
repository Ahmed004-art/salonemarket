import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/presentation/widgets/empty_state_view.dart';
import '../../data/models/cart_item_model.dart';
import '../controllers/cart_notifier.dart';

/// Shopping Cart screen for reviewing items, adjusting quantities, and calculating totals.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartNotifier = context.watch<CartNotifier>();
    final items = cartNotifier.items.values.toList();

    return Scaffold(
      backgroundColor: SaloneColors.background,
      appBar: AppBar(
        title: Text(
          'Shopping Cart (${cartNotifier.itemCount})',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearCart(context),
              child: Text(
                'Clear',
                style: GoogleFonts.dmSans(
                  color: SaloneMarketTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyStateView(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message:
                  'Discover authentic Sierra Leonean food, fashion, crafts, and electronics.',
              actionLabel: 'Explore Marketplace',
              onAction: () => context.go(Routes.home),
            )
          : Column(
              children: [
                if (cartNotifier.hasUnavailableItems)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SaloneMarketTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: SaloneMarketTheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Some items exceed available stock. Please adjust quantities before checkout.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: SaloneMarketTheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _CartItemCard(item: item);
                    },
                  ),
                ),
                _CartSummaryBar(cartNotifier: cartNotifier),
              ],
            ),
    );
  }

  void _confirmClearCart(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear Cart?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove all items from your shopping cart?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SaloneMarketTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context.read<CartNotifier>().clear();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final maxStock =
        product.trackInventory ? product.stockQuantity : 99;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaloneMarketTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: product.primaryImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: product.primaryImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildFallback(),
                    )
                  : _buildFallback(),
            ),
          ),
          const SizedBox(width: 12),

          // Details & Controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: SaloneMarketTheme.error,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<CartNotifier>().removeItem(product.id);
                      },
                    ),
                  ],
                ),
                if (product.vendor != null)
                  Text(
                    product.vendor!.shopName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: SaloneMarketTheme.muted,
                    ),
                  ),
                if (product.trackInventory && item.quantity > maxStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Only $maxStock available in stock',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: SaloneMarketTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedTotalPrice,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                    // Stepper
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: SaloneMarketTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              if (item.quantity > 1) {
                                context.read<CartNotifier>().updateQuantity(
                                      product.id,
                                      item.quantity - 1,
                                    );
                              } else {
                                context
                                    .read<CartNotifier>()
                                    .removeItem(product.id);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.remove, size: 16),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${item.quantity}',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: item.quantity < maxStock
                                ? () {
                                    context
                                        .read<CartNotifier>()
                                        .updateQuantity(
                                          product.id,
                                          item.quantity + 1,
                                        );
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.add,
                                size: 16,
                                color: item.quantity < maxStock
                                    ? SaloneMarketTheme.primary
                                    : SaloneMarketTheme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return const ColoredBox(
      color: SaloneMarketTheme.surface,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: SaloneMarketTheme.muted,
        ),
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.cartNotifier});

  final CartNotifier cartNotifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cartNotifier.itemCount} items)',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                Text(
                  cartNotifier.formattedSubtotal,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaloneMarketTheme.accent,
                  foregroundColor: SaloneMarketTheme.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (cartNotifier.hasUnavailableItems) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please adjust items that exceed stock before proceeding to checkout.',
                          style: GoogleFonts.dmSans(fontSize: 13),
                        ),
                        backgroundColor: SaloneMarketTheme.error,
                      ),
                    );
                    return;
                  }
                  context.push(Routes.checkout);
                },
                child: Text(
                  'Proceed to Checkout',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
