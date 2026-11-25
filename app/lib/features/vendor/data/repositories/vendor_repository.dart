import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../marketplace/data/models/product_model.dart';
import '../../../marketplace/data/models/vendor_model.dart';
import '../models/vendor_dashboard_stats.dart';
import '../models/vendor_order_model.dart';

class VendorRepository {
  VendorRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Fetches the vendor profile owned by the currently authenticated user.
  Future<Vendor?> getMyVendorStore() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final response = await _client
        .from('vendors')
        .select()
        .eq('profile_id', uid)
        .maybeSingle();

    if (response == null) return null;
    return Vendor.fromMap(response);
  }

  /// Submits an application to become a verified vendor.
  Future<Map<String, dynamic>> applyForVendor({
    required String shopName,
    required String slug,
    String? description,
    String? phone,
    String? location,
    String? email,
  }) async {
    final response = await _client.rpc(
      'apply_for_vendor',
      params: {
        'p_shop_name': shopName,
        'p_slug': slug,
        'p_description': description,
        'p_phone': phone,
        'p_location': location ?? 'Freetown, Sierra Leone',
        'p_email': email,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetches real-time dashboard analytics for the vendor.
  Future<VendorDashboardStats> getDashboardStats(String vendorId) async {
    final response = await _client.rpc(
      'vendor_get_dashboard_stats',
      params: {'p_vendor_id': vendorId},
    );

    return VendorDashboardStats.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Fetches all products owned by this vendor.
  Future<List<Product>> getVendorProducts(String vendorId) async {
    final response = await _client
        .from('products')
        .select('''
          *,
          categories:category_id (name),
          product_images (id, product_id, url, alt_text, sort_order, is_primary)
        ''')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(Product.fromMap)
        .toList();
  }

  /// Creates or updates a product via trusted server RPC.
  Future<Map<String, dynamic>> saveProduct({
    required String vendorId,
    String? productId,
    required String name,
    String? description,
    required double price,
    double? compareAtPrice,
    double? costPrice,
    required int stockQuantity,
    String? categoryId,
    String? sku,
    String status = 'draft',
    String? imageUrl,
  }) async {
    final response = await _client.rpc(
      'vendor_save_product',
      params: {
        'p_vendor_id': vendorId,
        'p_product_id': productId,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_compare_at_price': compareAtPrice,
        'p_cost_price': costPrice,
        'p_stock_quantity': stockQuantity,
        'p_category_id': categoryId,
        'p_sku': sku,
        'p_status': status,
        'p_image_url': imageUrl,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Uploads product image to Supabase Storage 'product-images' bucket under `<vendor_id>/`.
  Future<String> uploadProductImage({
    required String vendorId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    final cleanFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\.]'), '_');
    final storagePath = '$vendorId/$cleanFileName';

    await _client.storage.from('product-images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    final publicUrl = _client.storage.from('product-images').getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Safely deactivates or deletes a product.
  Future<void> deactivateProduct(String vendorId, String productId) async {
    await _client
        .from('products')
        .update({'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', productId)
        .eq('vendor_id', vendorId);
  }

  /// Fetches orders belonging to this vendor.
  Future<List<VendorOrder>> getVendorOrders(String vendorId, {String? statusFilter}) async {
    var query = _client.from('vendor_orders').select('''
          *,
          profiles:customer_id (full_name, phone),
          customer_orders:customer_order_id (
            payment_status,
            payment_method,
            addresses:shipping_address_id (street_address, city)
          ),
          order_items (id, product_name, product_image_url, sku, quantity, unit_price, line_total)
        ''').eq('vendor_id', vendorId);

    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(VendorOrder.fromMap)
        .toList();
  }

  /// Fetches a single vendor order details.
  Future<VendorOrder?> getVendorOrderDetail(String vendorOrderId) async {
    final response = await _client.from('vendor_orders').select('''
          *,
          profiles:customer_id (full_name, phone),
          customer_orders:customer_order_id (
            payment_status,
            payment_method,
            addresses:shipping_address_id (street_address, city)
          ),
          order_items (id, product_name, product_image_url, sku, quantity, unit_price, line_total)
        ''').eq('id', vendorOrderId).maybeSingle();

    if (response == null) return null;
    return VendorOrder.fromMap(response);
  }

  /// Advances an order's fulfillment status via server-verified RPC.
  Future<Map<String, dynamic>> updateOrderStatus({
    required String vendorOrderId,
    required String newStatus,
    String? notes,
  }) async {
    final response = await _client.rpc(
      'vendor_update_order_status',
      params: {
        'p_vendor_order_id': vendorOrderId,
        'p_new_status': newStatus,
        'p_notes': notes,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }
}
