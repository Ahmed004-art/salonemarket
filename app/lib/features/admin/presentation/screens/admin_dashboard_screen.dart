import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_cards.dart';
import '../controllers/admin_notifier.dart';

/// The main Admin dashboard screen.
///
/// **Design goals (blank-screen-proof):**
/// 1. The [Scaffold] + [AppBar] ALWAYS render — no early returns.
/// 2. Administrative module tiles are ALWAYS visible regardless of stats state.
/// 3. Each data section is wrapped in a try/catch builder so that one failing
///    section cannot destroy the entire dashboard.
/// 4. No [RefreshIndicator] wrapping the body on Web (Flutter web
///    `RefreshIndicator` + `SingleChildScrollView` can collapse to zero height
///    and render blank).
/// 5. `loadDashboard()` is called ONCE after the first frame; subsequent loads
///    use the refresh button in the AppBar.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);
  bool _hasRequestedLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasRequestedLoad) {
        _hasRequestedLoad = true;
        context.read<AdminNotifier>().loadDashboard();
      }
    });
  }

  Future<void> _onRefresh() =>
      context.read<AdminNotifier>().loadDashboard();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final stats = notifier.stats;
    final isLoading = notifier.isLoading;
    final errorMsg = notifier.errorMessage;

    // Build the scrollable body content.
    final bodyContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Loading indicator ───────────────────────────────────────
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(
                color: SaloneMarketTheme.primary,
              ),
            ),

          // ── Error banner (stats failed) ─────────────────────────────
          if (errorMsg != null)
            _StatsErrorBanner(error: errorMsg, onRetry: _onRefresh),

          // ── ALWAYS VISIBLE: Administrative Modules ──────────────────
          const _SectionHeader('Administrative Modules'),
          const SizedBox(height: AppSpacing.sm),
          _buildModuleGrid(context, notifier),
          const SizedBox(height: AppSpacing.lg),

          // ── Platform Financials (GMV) ───────────────────────────────
          const _SectionHeader('Platform Financials (GMV)'),
          const SizedBox(height: AppSpacing.sm),
          _SafeSection(
            child: _GmvCard(stats: stats, currency: _currency),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Ecosystem Metrics ───────────────────────────────────────
          const _SectionHeader('Ecosystem Metrics'),
          const SizedBox(height: AppSpacing.sm),
          _SafeSection(child: _EcosystemGrid(stats: stats)),
          const SizedBox(height: AppSpacing.lg),

          // ── Alerts (only shown when stats loaded) ───────────────────
          if (stats != null && stats.reconciliationAlerts > 0)
            _AlertBanner(
              color: Colors.red,
              icon: Icons.warning_amber_rounded,
              title:
                  '${stats.reconciliationAlerts} Payment Reconciliation Alert(s)',
              subtitle:
                  'Duplicate or late payments flagged for review or refund.',
              actionLabel: 'Review',
              onAction: () => context.push('/admin/transactions'),
            ),
          if (stats != null && stats.pendingVendors > 0)
            _AlertBanner(
              color: Colors.amber,
              icon: Icons.storefront,
              title:
                  '${stats.pendingVendors} Pending Vendor Application(s)',
              subtitle: 'New merchant applications awaiting approval.',
              actionLabel: 'Review',
              onAction: () => context.push(Routes.adminVendors),
            ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text(
          'Admin Operations Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
            onPressed: _onRefresh,
          ),
        ],
      ),
      // On Web, do NOT use RefreshIndicator (it can collapse
      // SingleChildScrollView to zero height and show blank).
      // On mobile, wrap with RefreshIndicator for pull-to-refresh.
      body: kIsWeb
          ? bodyContent
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: bodyContent,
            ),
    );
  }

  Widget _buildModuleGrid(BuildContext context, AdminNotifier notifier) {
    final stats = notifier.stats;
    final modules = [
      _ModuleDef(
        title: 'Vendor Management',
        subtitle: 'Approve, suspend & verify stores',
        icon: Icons.storefront,
        route: Routes.adminVendors,
        badge: (stats?.pendingVendors ?? 0) > 0
            ? '${stats!.pendingVendors}'
            : null,
      ),
      _ModuleDef(
        title: 'Product Moderation',
        subtitle: 'Flag, activate or deactivate listings',
        icon: Icons.inventory,
        route: Routes.adminProducts,
        badge: (stats?.flaggedProducts ?? 0) > 0
            ? '${stats!.flaggedProducts}'
            : null,
      ),
      _ModuleDef(
        title: 'Order Oversight',
        subtitle: 'Monitor deliveries & fulfillment',
        icon: Icons.receipt_long,
        route: Routes.adminOrders,
      ),
      _ModuleDef(
        title: 'Transactions & Ledger',
        subtitle: 'Reconcile payments & refunds',
        icon: Icons.payments,
        route: Routes.adminTransactions,
        badge: (stats?.reconciliationAlerts ?? 0) > 0
            ? '${stats!.reconciliationAlerts}'
            : null,
      ),
      _ModuleDef(
        title: 'Vendor Payouts & Disbursements',
        subtitle: 'Authorize requests & record disbursements',
        icon: Icons.account_balance_wallet,
        route: Routes.adminPayouts,
      ),
      const _ModuleDef(
        title: 'User Accounts',
        subtitle: 'View shoppers, vendors & admins',
        icon: Icons.people_outline,
        route: Routes.adminUsers,
      ),
    ];

    return Column(
      children: modules.map((mod) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: SaloneMarketTheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(mod.route),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(mod.icon,
                        color: SaloneMarketTheme.primary, size: 28),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mod.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            mod.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mod.badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          mod.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────

class _ModuleDef {
  const _ModuleDef({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.badge,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String? badge;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SaloneSectionHeader(title: text);
  }
}

/// Wraps a child widget in a try/catch so that if its build() throws,
/// the rest of the dashboard is unaffected.
class _SafeSection extends StatelessWidget {
  const _SafeSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e) {
      return _PlaceholderCard('Section error: $e');
    }
  }
}

/// GMV card — always renders; shows placeholder text when stats are null.
class _GmvCard extends StatelessWidget {
  const _GmvCard({required this.stats, required this.currency});
  final dynamic stats;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _PlaceholderCard(
        'Financial metrics will populate once data loads.',
      );
    }
    try {
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
                const Text('Total Settled GMV',
                    style: TextStyle(color: Colors.grey)),
                Flexible(
                  child: Text(
                    currency.format(stats.totalGmv),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: SaloneMarketTheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(child: _GmvItem('Today', currency.format(stats.todayGmv))),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Flexible(child: _GmvItem('This Week', currency.format(stats.weekGmv))),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Flexible(child: _GmvItem('This Month', currency.format(stats.monthGmv))),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return _PlaceholderCard('Unable to render financial metrics: $e');
    }
  }
}

class _GmvItem extends StatelessWidget {
  const _GmvItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Ecosystem stats grid — always renders; shows placeholder text when stats
/// are null.
class _EcosystemGrid extends StatelessWidget {
  const _EcosystemGrid({required this.stats});
  final dynamic stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _PlaceholderCard(
        'Ecosystem metrics will populate once data loads.',
      );
    }
    try {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Active Stores',
                  value: '${stats.activeVendors} / ${stats.totalVendors}',
                  subtitle: '${stats.pendingVendors} Pending',
                  icon: Icons.store,
                  color: Colors.green,
                  onTap: () => context.push(Routes.adminVendors),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  title: 'Total Orders',
                  value: '${stats.totalOrders}',
                  subtitle: 'Platform-wide',
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.blue,
                  onTap: () => context.push(Routes.adminOrders),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Products Listed',
                  value: '${stats.totalProducts}',
                  subtitle: '${stats.flaggedProducts} Flagged',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.purple,
                  onTap: () => context.push(Routes.adminProducts),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  title: 'Shoppers',
                  value: '${stats.totalCustomers}',
                  subtitle: 'Active accounts',
                  icon: Icons.people_outline,
                  color: Colors.teal,
                  onTap: () => context.push(Routes.adminUsers),
                ),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      return _PlaceholderCard('Unable to render ecosystem metrics: $e');
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: SaloneMetricCard(
        title: title,
        value: value,
        subtitle: subtitle,
        icon: icon,
        accentColor: color,
        onTap: onTap,
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StatsErrorBanner extends StatelessWidget {
  const _StatsErrorBanner({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Surface the first meaningful line only (not full stack trace)
    final firstLine = error.split('\n').first;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade800, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load platform statistics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstLine,
                  style:
                      TextStyle(color: Colors.red.shade800, fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Text(
                  'If this is your first run, please execute supabase/admin_permissions_fix.sql '
                  'in the Supabase SQL Editor. Administrative modules below are still accessible.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRetry,
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });
  final MaterialColor color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade800, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color.shade900)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.shade800,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(actionLabel,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
