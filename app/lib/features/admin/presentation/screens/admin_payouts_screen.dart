import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/admin_payout_notifier.dart';
import '../../data/models/admin_payout_model.dart';
import '../widgets/admin_error_state.dart';

/// Screen allowing administrators to review, approve, disburse, or reject vendor payout requests.
class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminPayoutNotifier>().loadPayouts();
    });
  }

  void _showDisburseDialog(BuildContext context, AdminPayoutItem payout) {
    String method = 'manual';
    final refSuffix = payout.payoutReference.length > 3
        ? payout.payoutReference.substring(3)
        : payout.payoutReference;
    final refController = TextEditingController(
      text: 'EXT-$refSuffix',
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Disburse Payout: ${payout.payoutReference}',
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
                  'Vendor: ${payout.vendorName}',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Amount: ${payout.formattedAmount}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  'Destination: ${payout.destinationProvider.toUpperCase()} (${payout.maskedAccountNumber})',
                  style: GoogleFonts.dmSans(fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration:
                      const InputDecoration(labelText: 'Disbursement Method'),
                  items: const [
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Manual Transfer (Orange/AfriMoney/Bank)'),
                    ),
                    DropdownMenuItem(
                      value: 'monime_payout',
                      child: Text('Monime API Automated Payout'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => method = val);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'Provider / Bank Reference',
                    hintText: 'e.g. TxID / OM-87421345',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Notes (Optional)',
                    hintText: 'e.g. Verified via Orange Money agent',
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
                Navigator.of(ctx).pop();
                final res = await context
                    .read<AdminPayoutNotifier>()
                    .approveAndDisburse(
                      payoutId: payout.id,
                      disbursementMethod: method,
                      providerRef: refController.text.trim().isEmpty
                          ? null
                          : refController.text.trim(),
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );

                if (context.mounted) {
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payout successfully marked as disbursed!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ??
                            'Failed to disburse payout'),
                        backgroundColor: SaloneMarketTheme.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Confirm Disbursement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AdminPayoutItem payout) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Reject Payout Request',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting this request will restore ${payout.formattedAmount} back to the vendor\'s available balance.',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                hintText: 'e.g. Invalid account name or phone number',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final res = await context.read<AdminPayoutNotifier>().rejectPayout(
                    payoutId: payout.id,
                    reason: reasonController.text.trim(),
                  );

              if (context.mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payout request rejected and balance restored'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ??
                          'Failed to reject payout'),
                      backgroundColor: SaloneMarketTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SaloneMarketTheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminPayoutNotifier>();
    final payouts = notifier.payouts;
    final isLoading = notifier.isLoading;
    final error = notifier.errorMessage;

    Widget listContent;
    if (isLoading && payouts.isEmpty) {
      listContent = const Center(child: CircularProgressIndicator());
    } else if (error != null && payouts.isEmpty) {
      listContent = AdminErrorState(
        title: 'Could not load payout requests',
        error: error,
        onRetry: () => notifier.loadPayouts(),
      );
    } else if (payouts.isEmpty) {
      listContent = _buildEmptyState();
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: payouts.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = payouts[index];
          return _buildPayoutCard(context, item);
        },
      );
      listContent = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadPayouts(),
              color: SaloneMarketTheme.primary,
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Vendor Payout Management',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadPayouts(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(notifier.selectedStatus),

          // Payout Requests List
          Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(String currentStatus) {
    final filters = [
      {'id': 'all', 'label': 'All'},
      {'id': 'pending', 'label': 'Pending'},
      {'id': 'completed', 'label': 'Disbursed'},
      {'id': 'rejected', 'label': 'Rejected'},
    ];

    return Container(
      color: SaloneMarketTheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = currentStatus == f['id'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: ChoiceChip(
                label: Text(
                  f['label']!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                  context.read<AdminPayoutNotifier>().loadPayouts(status: f['id']!);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayoutCard(BuildContext context, AdminPayoutItem payout) {
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
            // Top Row: Vendor & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    payout.vendorName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  payout.formattedAmount,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${payout.payoutReference} • ${payout.formattedDate}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Destination details
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SaloneMarketTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    payout.destinationType == 'mobile_money'
                        ? Icons.phone_android
                        : Icons.account_balance,
                    size: 16,
                    color: SaloneMarketTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${payout.destinationProvider.toUpperCase()}: ${payout.maskedAccountNumber} (${payout.destinationAccountName})',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildStatusChip(payout.status),
                ],
              ),
            ),

            if (payout.providerReference != null) ...[
              const SizedBox(height: 6),
              Text(
                'Provider Reference: ${payout.providerReference}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: SaloneMarketTheme.textSecondary,
                ),
              ),
            ],

            if (payout.failureReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Rejection Reason: ${payout.failureReason}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: SaloneMarketTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // Actions for Pending Payouts
            if (payout.isPending) ...[
              const Divider(height: 20, color: SaloneMarketTheme.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _showRejectDialog(context, payout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SaloneMarketTheme.error,
                      side: const BorderSide(color: SaloneMarketTheme.error),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () => _showDisburseDialog(context, payout),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaloneMarketTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Disburse Funds'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
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

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No payout requests in this filter category.',
        style: GoogleFonts.dmSans(color: SaloneMarketTheme.textSecondary),
      ),
    );
  }
}
