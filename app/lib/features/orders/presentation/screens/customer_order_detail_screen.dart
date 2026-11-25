import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/presentation/widgets/product_review_dialog.dart';
import '../../data/models/customer_order_model.dart';
import '../../data/repositories/customer_orders_repository.dart';

/// Screen displaying full details for a customer order, items, addresses, and receipts.
class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  final _repository = CustomerOrdersRepository();
  CustomerOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final order = await _repository.getOrderById(widget.orderId);

    if (!mounted) return;

    if (order != null) {
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Could not load order details.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _order == null
                  ? const Center(child: Text('Order not found'))
                  : _buildContent(context, _order!),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: SaloneMarketTheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage ?? 'An error occurred',
              style: GoogleFonts.dmSans(color: SaloneMarketTheme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loadOrder,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CustomerOrder order) {
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: SaloneMarketTheme.border),
            ),
            color: SaloneMarketTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #$shortId',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        order.formattedDate,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: SaloneMarketTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _buildStatusBadge(
                        order.isPaid ? 'Payment: Paid' : 'Payment: ${order.paymentStatus}',
                        isPositive: order.isPaid,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildStatusBadge(
                        'Fulfillment: ${order.status}',
                        isPositive: order.isFulfilled,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Buttons: Track Order & Receipt
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push(
                      Routes.orderTracking.replaceFirst(':orderId', order.id),
                      extra: order,
                    );
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Track Order'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push(Routes.receipt.replaceFirst(':orderId', order.id));
                  },
                  icon: const Icon(Icons.receipt_outlined, size: 18),
                  label: const Text('View Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaloneMarketTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Items Section
          Text(
            'Items (${order.items.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: SaloneMarketTheme.border),
            ),
            color: SaloneMarketTheme.surface,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: SaloneMarketTheme.border),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  title: Text(
                    item.productName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${item.quantity} x ${item.formattedPrice}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.formattedTotal,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (order.isPaid && item.productId != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: const Icon(Icons.star_outline, color: SaloneMarketTheme.accent),
                          tooltip: 'Review Product',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ProductReviewDialog(
                                productId: item.productId!,
                                productName: item.productName,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Delivery Address
          if (order.shippingAddress != null) ...[
            Text(
              'Delivery Address',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: SaloneMarketTheme.border),
              ),
              color: SaloneMarketTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shippingAddress!['recipient_name']?.toString() ?? 'Customer',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.shippingAddress!['street_address']?.toString() ?? '',
                      style: GoogleFonts.dmSans(fontSize: 13),
                    ),
                    Text(
                      '${order.shippingAddress!['city'] ?? ''}, ${order.shippingAddress!['region'] ?? ''}',
                      style: GoogleFonts.dmSans(fontSize: 13, color: SaloneMarketTheme.textSecondary),
                    ),
                    if (order.shippingAddress!['phone'] != null)
                      Text(
                        'Phone: ${order.shippingAddress!['phone']}',
                        style: GoogleFonts.dmSans(fontSize: 13, color: SaloneMarketTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Order Summary
          Text(
            'Order Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: SaloneMarketTheme.border),
            ),
            color: SaloneMarketTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', order.formattedSubtotal),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Delivery Fee', order.formattedDeliveryFee),
                  if (order.platformFee > 0) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow('Platform Fee', 'SLE ${order.platformFee.toStringAsFixed(2)}'),
                  ],
                  const Divider(height: 24, color: SaloneMarketTheme.border),
                  _buildSummaryRow(
                    'Total',
                    order.formattedTotal,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )
              : GoogleFonts.dmSans(
                  fontSize: 14,
                  color: SaloneMarketTheme.textSecondary,
                ),
        ),
        Text(
          value,
          style: isTotal
              ? GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: SaloneMarketTheme.primary,
                )
              : GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, {bool isPositive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPositive ? Colors.green.shade800 : Colors.blue.shade800,
        ),
      ),
    );
  }
}
