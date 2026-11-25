import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/admin_notifier.dart';
import '../widgets/admin_error_state.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNotifier>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final txs = notifier.transactions;
    final isLoading = notifier.isTransactionsLoading && txs.isEmpty;
    final error = notifier.transactionsError;

    Widget bodyContent;
    if (isLoading) {
      bodyContent = const Center(
          child: CircularProgressIndicator(color: SaloneMarketTheme.primary));
    } else if (error != null && txs.isEmpty) {
      bodyContent = AdminErrorState(
        title: 'Could not load transactions',
        error: error,
        onRetry: () => notifier.loadTransactions(),
      );
    } else if (txs.isEmpty) {
      bodyContent = const Center(child: Text('No transactions recorded'));
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: txs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final tx = txs[index];
          return _buildTxCard(context, tx);
        },
      );
      bodyContent = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadTransactions(),
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Transactions & Reconciliation'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadTransactions(),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildTxCard(BuildContext context, Map<String, dynamic> tx) {
    final ref = tx['reference']?.toString() ?? 'TX';
    final amount = ((tx['amount'] as num?)?.toDouble()) ?? 0.0;
    final status = tx['status']?.toString() ?? 'pending';
    final type = tx['type']?.toString() ?? 'payment';
    final customerName = (tx['profiles'] is Map) ? tx['profiles']['full_name']?.toString() ?? 'User' : 'User';
    final created = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();

    final meta = (tx['metadata'] is Map) ? tx['metadata'] as Map : {};
    final isReconciliation = meta['reconciliation_needed'] == true;
    final reason = meta['reason']?.toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isReconciliation ? Colors.red.shade50 : SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isReconciliation ? Colors.red.shade300 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isReconciliation ? Icons.warning_rounded : Icons.receipt,
                    color: isReconciliation ? Colors.red.shade800 : SaloneMarketTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(ref, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              _buildBadge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(_dateFormat.format(created), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const Divider(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $customerName', style: const TextStyle(fontSize: 12)),
                  Text('Type: ${type.toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              Text(
                _currency.format(amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SaloneMarketTheme.primary),
              ),
            ],
          ),

          if (isReconciliation) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason ?? 'Reconciliation needed: duplicate or late payment captured.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (status == 'succeeded') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'failed') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
