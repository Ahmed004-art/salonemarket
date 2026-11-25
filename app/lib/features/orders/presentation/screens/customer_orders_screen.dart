import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/customer_orders_notifier.dart';

/// Screen listing customer order history with filters and separate status indicators.
class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerOrdersNotifier>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CustomerOrdersNotifier>();
    final orders = notifier.orders;
    final isLoading = notifier.isLoading;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(context, notifier.currentFilter),

          // Content
          Expanded(
            child: isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => notifier.loadOrders(),
                    color: SaloneMarketTheme.primary,
                    child: orders.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
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

  Widget _buildFilterTabs(BuildContext context, String currentFilter) {
    final filters = [
      {'id': 'all', 'label': 'All'},
      {'id': 'active', 'label': 'Active'},
      {'id': 'completed', 'label': 'Completed'},
      {'id': 'cancelled', 'label': 'Cancelled'},
    ];

    return Container(
      color: SaloneMarketTheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = currentFilter == f['id'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: ChoiceChip(
                label: Text(
                  f['label']!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : SaloneMarketTheme.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: SaloneMarketTheme.primary,
                backgroundColor: SaloneMarketTheme.surfaceContainer,
                showCheckmark: false,
                onSelected: (_) {
                  context.read<CustomerOrdersNotifier>().setFilter(f['id']!);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, dynamic order) {
    final orderId = order.id as String;
    final shortId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SaloneMarketTheme.border),
      ),
      color: SaloneMarketTheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push(Routes.orderDetail.replaceFirst(':orderId', orderId));
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #$shortId',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    order.formattedDate as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Status Badges (Payment & Fulfillment distinct)
              Row(
                children: [
                  _buildPaymentBadge(order.paymentStatus as String),
                  const SizedBox(width: AppSpacing.xs),
                  _buildFulfillmentBadge(order.status as String),
                ],
              ),
              const Divider(height: 24, color: SaloneMarketTheme.border),

              // Items summary and Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} item(s)',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                  Text(
                    order.formattedTotal as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: SaloneMarketTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'paid':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Paid';
        break;
      case 'processing':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        label = 'Payment Processing';
        break;
      case 'failed':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Payment Failed';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildFulfillmentBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'fulfilled':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Delivered';
        break;
      case 'confirmed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Confirmed';
        break;
      case 'partially_fulfilled':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade800;
        label = 'Partially Fulfilled';
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Cancelled';
        break;
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: SaloneMarketTheme.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No orders found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You have no orders in this status category.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}
