import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/customer_order_model.dart';
import '../../data/repositories/customer_orders_repository.dart';

/// Screen displaying the fulfillment timeline and tracking progress for an order.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final CustomerOrder? initialOrder;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _repository = CustomerOrdersRepository();
  CustomerOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
    } else {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    final order = await _repository.getOrderById(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Track Order',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : _buildTimeline(context, _order!),
    );
  }

  Widget _buildTimeline(BuildContext context, CustomerOrder order) {
    // Determine milestone states
    final isPlaced = true;
    final isPaid = order.paymentStatus == 'paid';
    final isProcessing = order.status == 'confirmed' ||
        order.status == 'partially_fulfilled' ||
        order.status == 'fulfilled';
    final isShipped = order.status == 'partially_fulfilled' ||
        order.status == 'fulfilled';
    final isDelivered = order.status == 'fulfilled';
    final isCancelled = order.status == 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order summary card
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
                    'Tracking ID: ${order.id}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Placed on ${order.formattedDate}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                  if (isCancelled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'This order has been cancelled.',
                        style: GoogleFonts.dmSans(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Stepper Timeline
          Text(
            'Order Status Timeline',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildStep(
            title: 'Order Placed',
            subtitle: 'Your order was successfully recorded',
            isCompleted: isPlaced,
            isActive: !isPaid && !isCancelled,
            isLast: false,
          ),
          _buildStep(
            title: 'Payment Confirmed',
            subtitle: isPaid
                ? 'Payment received and verified'
                : 'Awaiting payment settlement',
            isCompleted: isPaid,
            isActive: isPaid && !isProcessing,
            isLast: false,
          ),
          _buildStep(
            title: 'Vendor Processing',
            subtitle: isProcessing
                ? 'Vendors are preparing your order items'
                : 'Pending vendor preparation',
            isCompleted: isProcessing,
            isActive: isProcessing && !isShipped,
            isLast: false,
          ),
          _buildStep(
            title: 'Shipped / In Transit',
            subtitle: isShipped
                ? 'Items are on the way to your delivery address'
                : 'Pending dispatch',
            isCompleted: isShipped,
            isActive: isShipped && !isDelivered,
            isLast: false,
          ),
          _buildStep(
            title: 'Delivered',
            subtitle: isDelivered
                ? 'Package has been delivered to customer'
                : 'Final delivery',
            isCompleted: isDelivered,
            isActive: isDelivered,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    final color = isCompleted
        ? SaloneMarketTheme.primary
        : (isActive ? SaloneMarketTheme.accent : Colors.grey.shade400);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? SaloneMarketTheme.primary : Colors.white,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? SaloneMarketTheme.accent : Colors.transparent,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isCompleted ? SaloneMarketTheme.primary : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isCompleted || isActive
                        ? SaloneMarketTheme.textPrimary
                        : SaloneMarketTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: SaloneMarketTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
