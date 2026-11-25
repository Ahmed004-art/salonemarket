import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../controllers/admin_notifier.dart';
import '../widgets/admin_error_state.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNotifier>().loadProducts();
    });
  }

  Future<void> _moderate(String productId, String name, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Moderate Listing'),
        content: Text('Change status of "$name" to $newStatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'flagged' ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = context.read<AdminNotifier>();
    final success = await notifier.updateProductStatus(productId, newStatus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Product status updated to $newStatus' : (notifier.productsError ?? 'Failed')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final products = notifier.products;
    final isLoading = notifier.isProductsLoading && products.isEmpty;
    final error = notifier.productsError;

    Widget listContent;
    if (isLoading) {
      listContent = const Center(
          child: CircularProgressIndicator(color: SaloneMarketTheme.primary));
    } else if (error != null && products.isEmpty) {
      listContent = AdminErrorState(
        title: 'Could not load products',
        error: error,
        onRetry: () => notifier.loadProducts(),
      );
    } else if (products.isEmpty) {
      listContent = const Center(child: Text('No products found'));
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final p = products[index];
          return _buildProductTile(context, p);
        },
      );
      listContent = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadProducts(),
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Product Moderation'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadProducts(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(notifier),
          Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AdminNotifier notifier) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Active', 'value': 'active'},
      {'label': 'Draft', 'value': 'draft'},
      {'label': 'Flagged', 'value': 'flagged'},
      {'label': 'Inactive', 'value': 'inactive'},
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
          final isSelected = notifier.productFilter == f['value'];
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
              notifier.loadProducts(filter: f['value']);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductTile(BuildContext context, Product p) {
    final imgUrl = p.images.isNotEmpty ? p.images.first.url : null;
    final vendorName = p.vendor?.shopName ?? 'Store';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imgUrl != null
                ? Image.network(
                    imgUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildBadge(p.status),
                  ],
                ),
                Text('Store: $vendorName • Cat: ${p.categoryName ?? "General"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(
                  '${_currency.format(p.price)} • Stock: ${p.stockQuantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (val) => _moderate(p.id, p.name, val),
            itemBuilder: (context) => [
              if (p.status != 'active')
                const PopupMenuItem(value: 'active', child: Text('Activate / Approve')),
              if (p.status != 'flagged')
                const PopupMenuItem(value: 'flagged', child: Text('Flag Listing', style: TextStyle(color: Colors.red))),
              if (p.status != 'inactive')
                const PopupMenuItem(value: 'inactive', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade100,
      child: const Icon(Icons.image, color: Colors.grey, size: 24),
    );
  }

  Widget _buildBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (status == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'flagged') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else if (status == 'draft') {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
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
