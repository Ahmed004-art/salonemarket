import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/admin_notifier.dart';
import '../widgets/admin_error_state.dart';

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNotifier>().loadVendors();
    });
  }

  Future<void> _updateStatus(String vendorId, String shopName, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus == "active" ? "Approve" : "Suspend"} Store'),
        content: Text('Are you sure you want to mark "$shopName" as $newStatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: Text(newStatus == 'active' ? 'Approve & Activate' : 'Suspend Store'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = context.read<AdminNotifier>();
    final success = await notifier.updateVendorStatus(vendorId, newStatus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Vendor updated to $newStatus' : (notifier.vendorsError ?? 'Update failed')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final vendors = notifier.vendors;
    final isLoading = notifier.isVendorsLoading && vendors.isEmpty;
    final error = notifier.vendorsError;

    Widget listContent;
    if (isLoading) {
      listContent = const Center(
          child: CircularProgressIndicator(color: SaloneMarketTheme.primary));
    } else if (error != null && vendors.isEmpty) {
      listContent = AdminErrorState(
        title: 'Could not load vendors',
        error: error,
        onRetry: () => notifier.loadVendors(),
      );
    } else if (vendors.isEmpty) {
      listContent = const Center(child: Text('No vendors found'));
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final v = vendors[index];
          return _buildVendorTile(context, v);
        },
      );
      listContent = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadVendors(),
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Vendor Management'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadVendors(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterBar(notifier),

          // Vendors List
          Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AdminNotifier notifier) {
    final filters = [
      {'label': 'All Stores', 'value': 'all'},
      {'label': 'Pending Approval', 'value': 'pending'},
      {'label': 'Active Stores', 'value': 'active'},
      {'label': 'Suspended', 'value': 'suspended'},
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
          final isSelected = notifier.vendorFilter == f['value'];
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
              notifier.loadVendors(filter: f['value']);
            },
          );
        },
      ),
    );
  }

  Widget _buildVendorTile(BuildContext context, Map<String, dynamic> v) {
    final status = v['status']?.toString() ?? 'pending';
    final shopName = v['shop_name']?.toString() ?? 'Store';
    final phone = v['phone']?.toString() ?? 'No phone';
    final location = v['location']?.toString() ?? 'Freetown';
    final ownerName = (v['profiles'] is Map) ? v['profiles']['full_name']?.toString() ?? 'Unknown' : 'Unknown';
    final commission = ((v['commission_rate'] as num?)?.toDouble() ?? 0.05) * 100;

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
              Expanded(
                child: Text(
                  shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildBadge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text('Owner: $ownerName • Phone: $phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text('Location: $location • Commission: ${commission.toInt()}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const Divider(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'pending')
                ElevatedButton.icon(
                  onPressed: () => _updateStatus(v['id'].toString(), shopName, 'active'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve Store'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              if (status == 'active')
                OutlinedButton.icon(
                  onPressed: () => _updateStatus(v['id'].toString(), shopName, 'suspended'),
                  icon: const Icon(Icons.block, size: 16, color: Colors.red),
                  label: const Text('Suspend', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              if (status == 'suspended')
                ElevatedButton.icon(
                  onPressed: () => _updateStatus(v['id'].toString(), shopName, 'active'),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Reactivate Store'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaloneMarketTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (status == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'pending') {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
    } else if (status == 'suspended') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
