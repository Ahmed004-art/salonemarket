import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../controllers/vendor_notifier.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  final _currency = NumberFormat.currency(symbol: 'SLE ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorNotifier>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<VendorNotifier>();
    final products = notifier.products;
    final isLoading = notifier.isLoading && products.isEmpty;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadProducts(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.vendorProductCreate),
        backgroundColor: SaloneMarketTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: SaloneMarketTheme.primary))
          : products.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: () => notifier.loadProducts(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildProductItem(context, product, notifier);
                    },
                  ),
                ),
    );
  }

  Widget _buildProductItem(BuildContext context, Product product, VendorNotifier notifier) {
    final primaryImage = product.images.isNotEmpty ? product.images.first.url : null;

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
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: primaryImage != null
                ? Image.network(
                    primaryImage,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(width: AppSpacing.md),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusPill(product.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(product.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: SaloneMarketTheme.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock: ${product.stockQuantity} units • SKU: ${product.sku ?? "N/A"}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'edit') {
                context.push('/vendor/products/${product.id}/edit', extra: product);
              } else if (val == 'deactivate') {
                notifier.deactivateProduct(product.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Product'),
                  ],
                ),
              ),
              if (product.status != 'inactive')
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Deactivate'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade100,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    if (status == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'draft') {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
    } else if (status == 'flagged') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No Products Listed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Tap the button below to add your first product.'),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => context.push(Routes.vendorProductCreate),
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(backgroundColor: SaloneMarketTheme.primary),
          ),
        ],
      ),
    );
  }
}
