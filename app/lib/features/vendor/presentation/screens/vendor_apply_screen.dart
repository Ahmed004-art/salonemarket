import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/vendor_notifier.dart';

class VendorApplyScreen extends StatefulWidget {
  const VendorApplyScreen({super.key});

  @override
  State<VendorApplyScreen> createState() => _VendorApplyScreenState();
}

class _VendorApplyScreenState extends State<VendorApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(text: 'Freetown, Sierra Leone');
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _onShopNameChanged(String val) {
    final slug = val
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slugCtrl.text = slug;
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final notifier = context.read<VendorNotifier>();

    final success = await notifier.applyForVendor(
      shopName: _shopNameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor application submitted successfully!')),
        );
        context.go(Routes.vendorDashboard);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.errorMessage ?? 'Submission failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<VendorNotifier>();
    final store = notifier.vendorStore;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('Vendor Application'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: store != null
            ? _buildExistingStoreCard(context, store)
            : _buildApplicationForm(context),
      ),
    );
  }

  Widget _buildExistingStoreCard(BuildContext context, dynamic store) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: SaloneMarketTheme.primary, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.shopName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Slug: ${store.slug}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(store.status),
            ],
          ),
          const Divider(height: 32),
          Text('Location: ${store.location ?? "Not specified"}'),
          const SizedBox(height: 8),
          Text('Phone: ${store.phone ?? "Not specified"}'),
          const SizedBox(height: 8),
          Text('Description: ${store.description ?? "None"}'),
          const SizedBox(height: 24),
          if (store.status == 'active')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(Routes.vendorDashboard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaloneMarketTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Go to Vendor Dashboard',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Your application is currently pending approval by SaloneMarket administrators. You will be notified once activated.',
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Register Your Store',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete your details to start selling products on SaloneMarket.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.lg),

          TextFormField(
            controller: _shopNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Shop Name *',
              hintText: 'e.g., Freetown Agro Supplies',
              prefixIcon: Icon(Icons.storefront),
            ),
            onChanged: _onShopNameChanged,
            validator: (v) => v == null || v.trim().isEmpty ? 'Shop name is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _slugCtrl,
            decoration: const InputDecoration(
              labelText: 'Shop Handle / URL Slug *',
              hintText: 'e.g., freetown-agro-supplies',
              prefixIcon: Icon(Icons.link),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Slug is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Business Phone Number *',
              hintText: '+232 76 123456',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Shop Location *',
              hintText: 'e.g., 14 Siaka Stevens Street, Freetown',
              prefixIcon: Icon(Icons.location_on),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Shop Description',
              hintText: 'Tell shoppers what products you offer...',
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Submit Application',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: fg),
      ),
    );
  }
}
