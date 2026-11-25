import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vendor_order_model.dart';
import '../controllers/vendor_notifier.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorNotifier>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<VendorNotifier>();
    final orders = notifier.orders;
    final isLoading = notifier.isLoading && orders.isEmpty;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(notifier),

          // Orders List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: SaloneMarketTheme.primary))
                : orders.isEmpty
                    ? _buildEmptyOrders()
                    : RefreshIndicator(
                        onRefresh: () => notifier.loadOrders(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderCard(context, order);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(VendorNotifier notifier) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Confirmed', 'value': 'confirmed'},
      {'label': 'Processing', 'value': 'processing'},
      {'label': 'Ready', 'value': 'ready_for_pickup'},
      {'label': 'Shipped', 'value': 'shipped'},
      {'label': 'Delivered', 'value': 'delivered'},
      {'label': 'Cancelled', 'value': 'cancelled'},
    ];

    return Container(
      color: SaloneMarketTheme.surface,
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = notifier.orderFilter == f['value'];
          return ChoiceChip(
            label: Text(f['label']!),
            selected: isSelected,
            selectedColor: SaloneMarketTheme.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) {
              notifier.loadOrders(status: f['value']);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, VendorOrder order) {
    return InkWell(
      onTap: () => context.push('/vendor/orders/${order.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.customerOrderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                _buildStatusPill(order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _dateFormat.format(order.createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: ${order.customerName ?? "Shopper"}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text('Payment: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        _buildPaymentPill(order.paymentStatus),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Payout', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      _currency.format(order.vendorPayout),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SaloneMarketTheme.primary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    switch (status) {
      case 'confirmed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'processing':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'ready_for_pickup':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade800;
        break;
      case 'shipped':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'delivered':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildPaymentPill(String payStatus) {
    final isPaid = payStatus == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        payStatus.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green.shade800 : Colors.amber.shade800,
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: AppSpacing.md),
          Text('No orders in this category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
