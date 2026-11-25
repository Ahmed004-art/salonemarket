import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_stats_model.dart';
import '../../../marketplace/data/models/product_model.dart';

class AdminRepository {
  AdminRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches real-time platform statistics with safe timeout and error parsing
  Future<AdminPlatformStats> getPlatformStats() async {
    try {
      final response = await _client
          .rpc('admin_get_platform_stats')
          .timeout(const Duration(seconds: 8));

      if (response == null) {
        throw 'Empty response from admin_get_platform_stats';
      }

      Map<String, dynamic> data;
      if (response is Map) {
        data = Map<String, dynamic>.from(response);
      } else if (response is String) {
        final decoded = jsonDecode(response);
        data = Map<String, dynamic>.from(decoded as Map);
      } else {
        throw 'Unexpected response type from server: ${response.runtimeType}';
      }

      return AdminPlatformStats.fromMap(data);
    } on PostgrestException catch (e) {
      debugPrint('🚨 [AdminRepository.getPlatformStats] PostgrestException: ${e.message} (code: ${e.code})');
      rethrow;
    } catch (e, stack) {
      debugPrint('🚨 [AdminRepository.getPlatformStats] Exception: $e\n$stack');
      rethrow;
    }
  }

  static const Duration _timeout = Duration(seconds: 10);

  /// Lists all vendors on the platform
  Future<List<Map<String, dynamic>>> getVendors({String? statusFilter}) async {
    var query = _client.from('vendors').select('''
      *,
      profiles:profile_id (full_name, phone)
    ''');

    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Updates vendor verification status (Approve, Suspend)
  Future<Map<String, dynamic>> updateVendorStatus({
    required String vendorId,
    required String status,
    double? commissionRate,
  }) async {
    final response = await _client.rpc(
      'admin_update_vendor_status',
      params: {
        'p_vendor_id': vendorId,
        'p_status': status,
        'p_commission_rate': commissionRate,
      },
    ).timeout(_timeout);

    return Map<String, dynamic>.from(response as Map);
  }

  /// Lists all products platform-wide for moderation
  Future<List<Product>> getProducts({String? statusFilter}) async {
    var query = _client.from('products').select('''
      *,
      vendors:vendor_id (shop_name),
      categories:category_id (name),
      product_images (id, product_id, url, is_primary)
    ''');

    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_timeout);
    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(Product.fromMap)
        .toList();
  }

  /// Updates product moderation status (active, flagged, inactive)
  Future<Map<String, dynamic>> updateProductStatus({
    required String productId,
    required String status,
  }) async {
    final response = await _client.rpc(
      'admin_update_product_status',
      params: {
        'p_product_id': productId,
        'p_status': status,
      },
    ).timeout(_timeout);

    return Map<String, dynamic>.from(response as Map);
  }

  /// Lists all customer orders across all vendors
  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _client.from('customer_orders').select('''
      *,
      profiles:customer_id (full_name, phone),
      vendor_orders (id, vendor_id, status, vendor_payout, vendors (shop_name))
    ''').order('created_at', ascending: false).limit(50).timeout(_timeout);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Lists all transactions and settlement records
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _client.from('transactions').select('''
      *,
      profiles:customer_id (full_name)
    ''').order('created_at', ascending: false).limit(50).timeout(_timeout);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Lists registered users / profiles
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_timeout);

    return List<Map<String, dynamic>>.from(response as List);
  }
}
