import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../controllers/vendor_notifier.dart';

class VendorProductFormScreen extends StatefulWidget {
  const VendorProductFormScreen({super.key, this.existingProduct});

  final Product? existingProduct;

  @override
  State<VendorProductFormScreen> createState() => _VendorProductFormScreenState();
}

class _VendorProductFormScreenState extends State<VendorProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _comparePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _imageUrlCtrl;
  String _status = 'draft';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toString() : '');
    _comparePriceCtrl = TextEditingController(
      text: p?.compareAtPrice != null ? p!.compareAtPrice.toString() : '',
    );
    _stockCtrl = TextEditingController(text: p != null ? p.stockQuantity.toString() : '10');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _imageUrlCtrl = TextEditingController(
      text: (p?.images.isNotEmpty == true) ? p!.images.first.url : '',
    );
    _status = p?.status ?? 'draft';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _comparePriceCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final notifier = context.read<VendorNotifier>();

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final comparePrice = double.tryParse(_comparePriceCtrl.text.trim());
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    final success = await notifier.saveProduct(
      productId: widget.existingProduct?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: price,
      compareAtPrice: comparePrice,
      stockQuantity: stock,
      sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
      status: _status,
      imageUrl: _imageUrlCtrl.text.trim().isNotEmpty ? _imageUrlCtrl.text.trim() : null,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingProduct != null ? 'Product updated!' : 'Product created!'),
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.errorMessage ?? 'Failed to save product'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProduct != null;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'New Product'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g., Premium Sierra Leone Coffee Beans',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Price (SLE) *',
                        hintText: '250.00',
                        prefixText: 'SLE ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Price required';
                        final val = double.tryParse(v);
                        if (val == null || val < 0) return 'Invalid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _comparePriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Original Price',
                        hintText: '300.00',
                        prefixText: 'SLE ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity *',
                        hintText: '10',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Stock required';
                        final val = int.tryParse(v);
                        if (val == null || val < 0) return 'Invalid stock';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SKU Code',
                        hintText: 'CF-SL-001',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft (Unlisted)')),
                  DropdownMenuItem(value: 'active', child: Text('Active (Live in Store)')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive (Archived)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product Image URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product Description',
                  hintText: 'Describe ingredients, dimensions, origin...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: SaloneMarketTheme.primary),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Update Product' : 'Publish Product',
                          style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
