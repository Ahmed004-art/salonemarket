import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vendor_order_model.dart';
import '../controllers/vendor_notifier.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  const VendorOrderDetailScreen({super.key, required this.vendorOrderId});

  final String vendorOrderId;

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorNotifier>().loadOrderDetail(widget.vendorOrderId);
    });
  }

  Future<void> _advanceStatus(String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Status Update'),
        content: Text('Update order fulfillment status to "${newStatus.replaceAll('_', ' ')}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: SaloneMarketTheme.primary),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    final notifier = context.read<VendorNotifier>();
    final success = await notifier.updateOrderStatus(widget.vendorOrderId, newStatus);
    setState(() => _isUpdating = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.errorMessage ?? 'Update failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<VendorNotifier>();
    final order = notifier.currentOrder;
    final isLoading = notifier.isLoading && order == null;

    if (isLoading) {
      return Scaffold(
        backgroundColor: SaloneMarketTheme.background,
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator(color: SaloneMarketTheme.primary)),
      );
    }

    if (order == null) {
      return Scaffold(
        backgroundColor: SaloneMarketTheme.background,
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final nextStatuses = order.allowableNextStatuses;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text('Order #${order.customerOrderId.substring(0, 8).toUpperCase()}'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Summary Card
            _buildStatusHeader(context, order),
            const SizedBox(height: AppSpacing.md),

            // Customer & Delivery Details
            _buildCustomerCard(context, order),
            const SizedBox(height: AppSpacing.md),

            // Order Items
            _buildItemsCard(context, order),
            const SizedBox(height: AppSpacing.md),

            // Payout Summary
            _buildFinancialCard(context, order),
            const SizedBox(height: AppSpacing.xl),

            // Status Actions (If allowed)
            if (nextStatuses.isNotEmpty) ...[
              const Text(
                'Fulfillment Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: nextStatuses.map((st) {
                  return ElevatedButton.icon(
                    onPressed: _isUpdating ? null : () => _advanceStatus(st),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Mark as ${st.replaceAll("_", " ").toUpperCase()}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: st == 'cancelled' ? Colors.red : SaloneMarketTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );
                }).toList(),
              ),
            ] else if (!order.isPaid) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.amber.shade900),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'This order is awaiting customer payment. Vendors cannot advance fulfillment status until payment is confirmed.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, VendorOrder order) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fulfillment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildBadge(order.status, isFulfillment: true),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildBadge(order.paymentStatus, isFulfillment: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, VendorOrder order) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer & Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Recipient: ${order.customerName ?? "Shopper"}'),
          if (order.customerPhone != null) Text('Phone: ${order.customerPhone}'),
          if (order.shippingAddress != null) Text('Address: ${order.shippingAddress}'),
          if (order.notes != null) Text('Notes: ${order.notes}', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, VendorOrder order) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ordered Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Qty: ${item.quantity} × ${_currency.format(item.unitPrice)}'),
                trailing: Text(_currency.format(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(BuildContext context, VendorOrder order) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal'),
              Text(_currency.format(order.subtotal)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Commission (5%)'),
              Text('- ${_currency.format(order.commissionAmount)}', style: const TextStyle(color: Colors.red)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Vendor Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                _currency.format(order.vendorPayout),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: SaloneMarketTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String val, {required bool isFulfillment}) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (val == 'paid' || val == 'delivered') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (val == 'processing' || val == 'confirmed') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else if (val == 'shipped') {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade800;
    } else if (val == 'cancelled' || val == 'failed') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        val.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
