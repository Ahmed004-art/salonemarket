import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/admin_notifier.dart';
import '../widgets/admin_error_state.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNotifier>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final orders = notifier.orders;
    final isLoading = notifier.isOrdersLoading && orders.isEmpty;
    final error = notifier.ordersError;

    Widget bodyContent;
    if (isLoading) {
      bodyContent = const Center(
          child: CircularProgressIndicator(color: SaloneMarketTheme.primary));
    } else if (error != null && orders.isEmpty) {
      bodyContent = AdminErrorState(
        title: 'Could not load orders',
        error: error,
        onRetry: () => notifier.loadOrders(),
      );
    } else if (orders.isEmpty) {
      bodyContent = const Center(child: Text('No orders found'));
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(context, order);
        },
      );
      bodyContent = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadOrders(),
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Platform Orders Oversight'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadOrders(),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> o) {
    final orderId = o['id']?.toString() ?? '';
    final shortOrderId =
        orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final total = ((o['total'] as num?)?.toDouble()) ?? 0.0;
    final status = o['status']?.toString() ?? 'pending_payment';
    final payStatus = o['payment_status']?.toString() ?? 'pending';
    final customerName = (o['profiles'] is Map) ? o['profiles']['full_name']?.toString() ?? 'Customer' : 'Customer';
    final vendorOrders = (o['vendor_orders'] is List) ? o['vendor_orders'] as List : [];
    final created = DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${shortOrderId.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _buildStatusPill(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(_dateFormat.format(created), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const Divider(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $customerName', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text('Payment: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      _buildPaymentPill(payStatus),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _currency.format(total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SaloneMarketTheme.primary),
                  ),
                ],
              ),
            ],
          ),

          if (vendorOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendor Splits (${vendorOrders.length} store(s)):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  ...vendorOrders.map((vo) {
                    final sname = (vo is Map && vo['vendors'] is Map) ? vo['vendors']['shop_name'] : 'Vendor';
                    final vstatus = (vo is Map) ? vo['status'] : '';
                    final payout = (vo is Map && vo['vendor_payout'] is num) ? (vo['vendor_payout'] as num).toDouble() : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• $sname ($vstatus)', style: const TextStyle(fontSize: 11)),
                          Text(_currency.format(payout), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    if (status == 'fulfilled') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'confirmed' || status == 'partially_fulfilled') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else if (status == 'cancelled' || status == 'payment_failed') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
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
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isPaid ? Colors.green.shade800 : Colors.amber.shade800),
      ),
    );
  }
}
