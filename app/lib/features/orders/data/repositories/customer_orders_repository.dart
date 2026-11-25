import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/customer_order_model.dart';

/// Repository for customer order history, details, and fulfillment tracking.
class CustomerOrdersRepository {
  CustomerOrdersRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient {
    if (_client != null) return _client;
    if (AppConstants.isSupabaseConfigured) {
      return Supabase.instance.client;
    }
    throw StateError('Supabase is not configured.');
  }

  bool get isReady => _client != null || AppConstants.isSupabaseConfigured;

  String? get currentUserId =>
      _client?.auth.currentUser?.id ?? SupabaseService.instance.currentUserId;

  /// Fetches orders for the currently authenticated customer.
  Future<List<CustomerOrder>> getOrders({String? statusFilter}) async {
    if (!isReady) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      var query = _effectiveClient
          .from('customer_orders')
          .select('''
            *,
            order_items (*),
            vendor_orders (*),
            shipping_address:addresses (*)
          ''')
          .eq('customer_id', userId);

      if (statusFilter != null && statusFilter != 'all') {
        if (statusFilter == 'active') {
          query = query.not('status', 'in', ['fulfilled', 'cancelled', 'refunded']);
        } else if (statusFilter == 'completed') {
          query = query.eq('status', 'fulfilled');
        } else if (statusFilter == 'cancelled') {
          query = query.inFilter('status', ['cancelled', 'refunded']);
        }
      }

      final response = await query.order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => CustomerOrder.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches full details for a single customer order.
  Future<CustomerOrder?> getOrderById(String orderId) async {
    if (!isReady) return null;
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final response = await _effectiveClient
          .from('customer_orders')
          .select('''
            *,
            order_items (*),
            vendor_orders (*),
            shipping_address:addresses (*)
          ''')
          .eq('id', orderId)
          .eq('customer_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return CustomerOrder.fromMap(response);
    } catch (_) {
      return null;
    }
  }
}
