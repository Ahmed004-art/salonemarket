import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/vendor_notifier.dart';
import '../controllers/vendor_payout_notifier.dart';
import '../../data/models/vendor_payout_model.dart';

/// Screen displaying vendor financial balances, payout requests, registered accounts, and earnings ledger.
class VendorPayoutsScreen extends StatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  State<VendorPayoutsScreen> createState() => _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends State<VendorPayoutsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final vendor = context.read<VendorNotifier>().vendor;
    if (vendor != null) {
      context.read<VendorPayoutNotifier>().loadPayoutData(vendor.id);
    }
  }

  void _showAddDestinationDialog(String vendorId) {
    String type = 'mobile_money';
    String provider = 'orange_money';
    final numberController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Add Payout Account',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'mobile_money',
                      child: Text('Mobile Money'),
                    ),
                    DropdownMenuItem(
                      value: 'bank_account',
                      child: Text('Bank Account'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        type = val;
                        provider = val == 'mobile_money' ? 'orange_money' : 'slcb';
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: provider,
                  decoration: const InputDecoration(labelText: 'Provider / Bank'),
                  items: type == 'mobile_money'
                      ? const [
                          DropdownMenuItem(
                            value: 'orange_money',
                            child: Text('Orange Money Sierra Leone'),
                          ),
                          DropdownMenuItem(
                            value: 'afrimoney',
                            child: Text('AfriMoney Sierra Leone'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                            value: 'slcb',
                            child: Text('Sierra Leone Commercial Bank (SLCB)'),
                          ),
                          DropdownMenuItem(
                            value: 'rokel',
                            child: Text('Rokel Commercial Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'gtbank',
                            child: Text('Guaranty Trust Bank (GTBank)'),
                          ),
                        ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => provider = val);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: numberController,
                  keyboardType: type == 'mobile_money'
                      ? TextInputType.phone
                      : TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'mobile_money'
                        ? 'Mobile Number (+232...)'
                        : 'Account Number',
                    hintText: type == 'mobile_money' ? '+232 76 123456' : '0030...',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account / Beneficiary Name',
                    hintText: 'e.g. Mariama Kamara',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (numberController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop();
                final ok = await context
                    .read<VendorPayoutNotifier>()
                    .addDestination(
                      vendorId: vendorId,
                      type: type,
                      provider: provider,
                      accountNumber: numberController.text.trim(),
                      accountName: nameController.text.trim(),
                    );
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payout destination added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save Destination'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestPayoutDialog(
    BuildContext context,
    String vendorId,
    VendorPayoutSummary summary,
    List<VendorPayoutDestination> destinations,
  ) {
    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a payout account first (Orange Money / AfriMoney / Bank).'),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    if (summary.availableBalance < 50.00) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum payout threshold is SLE 50.00. Available balance is insufficient.'),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    final amountController =
        TextEditingController(text: summary.availableBalance.toStringAsFixed(2));
    final notesController = TextEditingController();
    String selectedDestId = destinations.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Request Payout',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available: ${summary.formattedAvailable}',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Payout Amount (SLE)',
                    prefixText: 'SLE ',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: selectedDestId,
                  decoration:
                      const InputDecoration(labelText: 'Payout Destination'),
                  items: destinations.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.providerDisplayName} (${d.maskedAccountNumber})',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDestId = val);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'e.g. Weekly settlement',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt < 50.00 || amt > summary.availableBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid amount. Must be at least SLE 50 and <= available balance.'),
                      backgroundColor: SaloneMarketTheme.error,
                    ),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                final res = await context
                    .read<VendorPayoutNotifier>()
                    .submitPayoutRequest(
                      vendorId: vendorId,
                      amount: amt,
                      destinationId: selectedDestId,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );

                if (mounted) {
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ??
                            'Payout request submitted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            res['message']?.toString() ?? 'Failed to request payout'),
                        backgroundColor: SaloneMarketTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorNotifier>().vendor;
    final payoutState = context.watch<VendorPayoutNotifier>();
    final summary = payoutState.summary;
    final destinations = payoutState.destinations;
    final payouts = payoutState.payouts;
    final ledger = payoutState.ledgerEntries;
    final isLoading = payoutState.isLoading;

    if (vendor == null) {
      return const Scaffold(
        body: Center(child: Text('Vendor profile not found')),
      );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Payouts & Earnings',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading && summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Overview Card
                    _buildBalanceCard(context, vendor.id, summary, destinations),
                    const SizedBox(height: AppSpacing.md),

                    // Destinations Section
                    _buildDestinationsCard(context, vendor.id, destinations),
                    const SizedBox(height: AppSpacing.lg),

                    // Tabs: History vs Ledger
                    TabBar(
                      controller: _tabController,
                      labelColor: SaloneMarketTheme.primary,
                      unselectedLabelColor: SaloneMarketTheme.textSecondary,
                      indicatorColor: SaloneMarketTheme.primary,
                      tabs: const [
                        Tab(text: 'Payout Requests'),
                        Tab(text: 'Earnings Ledger'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPayoutsList(payouts),
                          _buildLedgerList(ledger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    String vendorId,
    VendorPayoutSummary? summary,
    List<VendorPayoutDestination> destinations,
  ) {
    final available = summary?.formattedAvailable ?? 'SLE 0.00';
    final earned = summary?.formattedTotalEarned ?? 'SLE 0.00';
    final pending = summary?.formattedPending ?? 'SLE 0.00';
    final paidOut = summary?.formattedTotalPaidOut ?? 'SLE 0.00';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SaloneMarketTheme.border),
      ),
      color: SaloneMarketTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available for Payout',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              available,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: SaloneMarketTheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: SaloneMarketTheme.border),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol('Net Earned', earned),
                _buildMetricCol('In-Flight Payouts', pending),
                _buildMetricCol('Total Disbursed', paidOut),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: summary != null
                    ? () => _showRequestPayoutDialog(
                        context, vendorId, summary, destinations)
                    : null,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text('Request Payout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaloneMarketTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: SaloneMarketTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationsCard(
    BuildContext context,
    String vendorId,
    List<VendorPayoutDestination> destinations,
  ) {
    return Card(
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
                  'Payout Accounts (${destinations.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddDestinationDialog(vendorId),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Account'),
                ),
              ],
            ),
            if (destinations.isEmpty)
              Text(
                'No payout destination registered. Add your Orange Money or AfriMoney number.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: SaloneMarketTheme.textSecondary,
                ),
              )
            else
              ...destinations.map((d) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    d.type == 'mobile_money'
                        ? Icons.phone_android
                        : Icons.account_balance,
                    color: SaloneMarketTheme.primary,
                  ),
                  title: Text(
                    '${d.providerDisplayName} - ${d.maskedAccountNumber}',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    d.accountName,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutsList(List<VendorPayout> payouts) {
    if (payouts.isEmpty) {
      return Center(
        child: Text(
          'No payout requests submitted yet.',
          style: GoogleFonts.dmSans(color: SaloneMarketTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: payouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final p = payouts[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: SaloneMarketTheme.border),
          ),
          color: SaloneMarketTheme.surface,
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.payoutReference,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.formattedAmount,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${p.destinationProvider.toUpperCase()} (${p.maskedAccountNumber}) • ${p.formattedDate}',
                  style: GoogleFonts.dmSans(fontSize: 12),
                ),
                if (p.providerReference != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${p.providerReference}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                ],
                if (p.failureReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reason: ${p.failureReason}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: SaloneMarketTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            trailing: _buildPayoutStatusChip(p.status),
          ),
        );
      },
    );
  }

  Widget _buildLedgerList(List<VendorLedgerEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No ledger activity recorded yet.',
          style: GoogleFonts.dmSans(color: SaloneMarketTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final e = entries[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: SaloneMarketTheme.border),
          ),
          color: SaloneMarketTheme.surface,
          child: ListTile(
            dense: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.reference,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  e.formattedNet,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: e.isCredit ? Colors.green.shade700 : SaloneMarketTheme.error,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    e.description!,
                    style: GoogleFonts.dmSans(fontSize: 11),
                  ),
                ],
                if (e.commissionAmount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Gross: SLE ${e.grossAmount.toStringAsFixed(2)} | 5% Commission: -SLE ${e.commissionAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPayoutStatusChip(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'processing':
      case 'approved':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'rejected':
      case 'failed':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
