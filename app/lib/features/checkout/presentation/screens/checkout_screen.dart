import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../address/data/models/address_model.dart';
import '../../../address/presentation/controllers/address_notifier.dart';
import '../../../address/presentation/screens/saved_addresses_screen.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';
import '../controllers/checkout_notifier.dart';

/// Checkout preparation screen for reviewing addresses, vendor items, and confirming orders.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressNotifier>().loadAddresses();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleChangeAddress() async {
    final selected = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(isSelectionMode: true),
      ),
    );
    if (!mounted || selected == null) return;
    context.read<AddressNotifier>().selectAddress(selected);
  }

  Future<void> _handlePlaceOrder() async {
    final addressNotifier = context.read<AddressNotifier>();
    final cartNotifier = context.read<CartNotifier>();
    final checkoutNotifier = context.read<CheckoutNotifier>();

    final address = addressNotifier.selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add or select a delivery address.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    if (cartNotifier.hasUnavailableItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some items in your cart are out of stock or exceed inventory.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    final success = await checkoutNotifier.processCheckout(
      items: cartNotifier.items.values.toList(),
      addressId: address.id,
      notes: _notesController.text,
    );

    if (mounted) {
      if (success) {
        final orderId =
            checkoutNotifier.lastResult?.customerOrderId ?? 'unknown';
        cartNotifier.clear();
        context.go(
          Routes.orderConfirmation.replaceFirst(':orderId', orderId),
          extra: checkoutNotifier.lastResult,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              checkoutNotifier.errorMessage ?? 'Checkout preparation failed.',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: SaloneMarketTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressNotifier = context.watch<AddressNotifier>();
    final cartNotifier = context.watch<CartNotifier>();
    final checkoutNotifier = context.watch<CheckoutNotifier>();

    final selectedAddress = addressNotifier.selectedAddress;
    final itemsByVendor = cartNotifier.itemsByVendor;
    final hasUnavailable = cartNotifier.hasUnavailableItems;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.surface,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: cartNotifier.items.isEmpty
          ? Center(
              child: Text(
                'Your cart is empty',
                style: GoogleFonts.plusJakartaSans(fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock / Availability Warning Banner
                  if (hasUnavailable) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SaloneMarketTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: SaloneMarketTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: SaloneMarketTheme.error,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Some items in your cart exceed available inventory. Adjust quantities in your cart before placing order.',
                              style: GoogleFonts.dmSans(
                                color: SaloneMarketTheme.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Section 1: Delivery Address ────────────────────────────
                  _buildSectionHeader(
                    title: '1. Delivery Address',
                    actionLabel: selectedAddress != null ? 'Change' : 'Add',
                    onAction: _handleChangeAddress,
                  ),
                  const SizedBox(height: 8),
                  _buildAddressCard(context, selectedAddress),
                  const SizedBox(height: 24),

                  // ── Section 2: Order Items (Grouped by Vendor) ─────────────
                  _buildSectionHeader(
                    title: '2. Review Items (${cartNotifier.itemCount})',
                  ),
                  const SizedBox(height: 8),
                  ...itemsByVendor.entries.map((entry) {
                    final vendorItems = entry.value;
                    final vendorName = vendorItems.first.product.vendor?.shopName ??
                        'Salone Merchant';
                    return _buildVendorGroupCard(vendorName, vendorItems);
                  }),
                  const SizedBox(height: 24),

                  // ── Section 3: Delivery Notes ──────────────────────────────
                  _buildSectionHeader(title: '3. Delivery Notes (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Special delivery instructions or landmark (e.g. Opposite Wilberforce Secondary School)',
                      hintStyle: GoogleFonts.dmSans(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Section 4: Authoritative Order Summary ─────────────────
                  _buildSectionHeader(title: '4. Order Summary'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SaloneMarketTheme.border),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Items Subtotal',
                          cartNotifier.formattedSubtotal,
                        ),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                          'Delivery Fee',
                          'Free',
                          isPositive: true,
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'Estimated Total',
                          cartNotifier.formattedSubtotal,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prices and stock availability are authoritatively verified by the server during order creation.',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: SaloneMarketTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SaloneMarketTheme.accent,
                        foregroundColor: SaloneMarketTheme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (hasUnavailable ||
                              selectedAddress == null ||
                              checkoutNotifier.isProcessing)
                          ? null
                          : _handlePlaceOrder,
                      child: checkoutNotifier.isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: SaloneMarketTheme.onAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Confirm & Place Order (${cartNotifier.formattedSubtotal})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: SaloneMarketTheme.primary,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: SaloneMarketTheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, Address? address) {
    if (address == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SaloneMarketTheme.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 32,
              color: SaloneMarketTheme.muted,
            ),
            const SizedBox(height: 8),
            Text(
              'No delivery address selected',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _handleChangeAddress,
              child: const Text('Add or Choose Address'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaloneMarketTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  address.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                address.recipientName,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: SaloneMarketTheme.primary,
                ),
              ),
              if (address.phone != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(${address.phone!})',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address.formattedAddress,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: SaloneMarketTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorGroupCard(String vendorName, List<CartItem> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaloneMarketTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: SaloneMarketTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: SaloneMarketTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  vendorName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Items in this vendor group
          ...items.map((item) {
            final product = item.product;
            final isUnavailable = !product.isInStock ||
                (product.trackInventory && item.quantity > product.stockQuantity);

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: product.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: SaloneMarketTheme.surface,
                                child: Icon(Icons.image_outlined, size: 20),
                              ),
                            )
                          : const ColoredBox(
                              color: SaloneMarketTheme.surface,
                              child: Icon(Icons.image_outlined, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} x ${product.formattedPrice}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: SaloneMarketTheme.muted,
                          ),
                        ),
                        if (isUnavailable)
                          Text(
                            'Exceeds inventory',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: SaloneMarketTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    item.formattedTotalPrice,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isPositive = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: SaloneMarketTheme.primary,
                )
              : GoogleFonts.dmSans(
                  fontSize: 14,
                  color: SaloneMarketTheme.muted,
                ),
        ),
        Text(
          value,
          style: isBold
              ? GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: SaloneMarketTheme.primary,
                )
              : GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isPositive
                      ? Colors.green.shade700
                      : SaloneMarketTheme.primary,
                ),
        ),
      ],
    );
  }
}
