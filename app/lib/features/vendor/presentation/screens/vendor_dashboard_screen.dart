import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_cards.dart';
import '../controllers/vendor_notifier.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorNotifier>().loadVendorProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorNotifier = context.watch<VendorNotifier>();
    final store = vendorNotifier.vendorStore;
    final stats = vendorNotifier.dashboardStats;
    final isLoading = vendorNotifier.isLoading && stats == null;

    final scrollBody = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Banner
          _buildStatusBanner(context, vendorNotifier),
          const SizedBox(height: AppSpacing.lg),

          if (vendorNotifier.isApproved && stats != null) ...[
            // 2. Overview Metrics Grid
            const SaloneSectionHeader(title: 'Store Overview'),
            const SizedBox(height: AppSpacing.sm),
            _buildMetricsGrid(context, stats),
            const SizedBox(height: AppSpacing.lg),

            // 3. Sales Breakdown
            const SaloneSectionHeader(title: 'Sales & Revenue'),
            const SizedBox(height: AppSpacing.sm),
            _buildSalesBreakdown(context, stats),
            const SizedBox(height: AppSpacing.lg),

            // 4. Quick Actions
            const SaloneSectionHeader(title: 'Store Management'),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButtons(context),
            const SizedBox(height: AppSpacing.lg),

            // 5. Recent Orders
            SaloneSectionHeader(
              title: 'Recent Orders',
              actionLabel: 'View All',
              onAction: () => context.push(Routes.vendorOrders),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildRecentOrders(context, stats),
          ] else if (!vendorNotifier.hasStore) ...[
            _buildNoStorePrompt(context),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: SaloneColors.background,
      appBar: AppBar(
        title: Text(
          store?.shopName.isNotEmpty == true ? store!.shopName : 'Vendor Portal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: SaloneColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vendorNotifier.loadVendorProfile(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: SaloneColors.primary),
            )
          : kIsWeb
              ? scrollBody
              : RefreshIndicator(
                  onRefresh: () => vendorNotifier.refreshDashboard(),
                  child: scrollBody,
                ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, VendorNotifier notifier) {
    if (!notifier.hasStore) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront, color: Colors.blue.shade800, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become a SaloneMarket Vendor',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                  const Text('Start selling your products across Sierra Leone.'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => context.push(Routes.vendorApplication),
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Apply Now'),
            ),
          ],
        ),
      );
    }

    if (notifier.isPending) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.amber.shade900, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Under Review',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                  ),
                  const Text('Your vendor application is pending administrator approval.'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (notifier.isSuspended) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: Colors.red.shade800, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Suspended',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                  ),
                  const Text('Your shop is suspended. Please contact SaloneMarket support.'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green.shade700, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Verified Active Vendor Store',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
          ),
          Text(
            '${((1 - (notifier.vendorStore?.commissionRate ?? 0.05)) * 100).toInt()}% Payout',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, dynamic stats) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          title: 'Total Products',
          value: stats.totalProducts.toString(),
          subtitle: '${stats.activeProducts} Active',
          icon: Icons.inventory_2_outlined,
          color: Colors.blue,
          onTap: () => context.push(Routes.vendorProducts),
        ),
        _buildMetricCard(
          title: 'Pending Orders',
          value: stats.pendingOrders.toString(),
          subtitle: 'Awaiting Action',
          icon: Icons.pending_actions_outlined,
          color: Colors.orange,
          onTap: () => context.push(Routes.vendorOrders),
        ),
        _buildMetricCard(
          title: 'Completed Orders',
          value: stats.completedOrders.toString(),
          subtitle: 'Delivered',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          onTap: () => context.push(Routes.vendorOrders),
        ),
        _buildMetricCard(
          title: 'Total Earnings',
          value: _currencyFormat.format(stats.totalSales),
          subtitle: 'Available Payouts',
          icon: Icons.payments_outlined,
          color: SaloneMarketTheme.primary,
          onTap: () => context.push(Routes.vendorPayouts),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesBreakdown(BuildContext context, dynamic stats) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSalesItem('Today', _currencyFormat.format(stats.todaySales)),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildSalesItem('This Week', _currencyFormat.format(stats.weekSales)),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildSalesItem('This Month', _currencyFormat.format(stats.monthSales)),
        ],
      ),
    );
  }

  Widget _buildSalesItem(String label, String amount) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push(Routes.vendorProductCreate),
                icon: const Icon(Icons.add_box, color: Colors.white),
                label: const Text(
                  'Add Product',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaloneMarketTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(Routes.vendorOrders),
                icon: const Icon(Icons.list_alt),
                label: const Text('Manage Orders'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.vendorPayouts),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Vendor Payouts & Balances'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context, dynamic stats) {
    final recent = stats.recentOrders;
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: SaloneMarketTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No recent orders found.'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final order = recent[index];
        return ListTile(
          tileColor: SaloneMarketTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Order #${order.customerOrderId.substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${order.customerName} • ${order.itemCount} item(s)',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(order.vendorPayout),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStatusPill(order.status),
            ],
          ),
          onTap: () => context.push('/vendor/orders/${order.id}'),
        );
      },
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color text;
    switch (status) {
      case 'confirmed':
        bg = Colors.blue.shade50;
        text = Colors.blue.shade800;
        break;
      case 'processing':
        bg = Colors.amber.shade50;
        text = Colors.amber.shade800;
        break;
      case 'shipped':
        bg = Colors.purple.shade50;
        text = Colors.purple.shade800;
        break;
      case 'delivered':
        bg = Colors.green.shade50;
        text = Colors.green.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildNoStorePrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront, size: 48, color: SaloneMarketTheme.primary),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No Vendor Store Registered',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'You are currently logged in as a customer. Apply to become a vendor to open your store.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => context.push(Routes.vendorApplication),
            style: ElevatedButton.styleFrom(backgroundColor: SaloneMarketTheme.primary),
            child: const Text('Apply for Vendor Store'),
          ),
        ],
      ),
    );
  }
}
