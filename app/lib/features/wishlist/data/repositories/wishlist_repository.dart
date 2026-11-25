import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/wishlist_item_model.dart';

/// Repository for customer product wishlist management.
class WishlistRepository {
  WishlistRepository({SupabaseClient? client}) : _client = client;

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

  /// Fetches all wishlist items for the authenticated customer.
  Future<List<WishlistItem>> getWishlist() async {
    if (!isReady) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await _effectiveClient
          .from('wishlists')
          .select('*, product:products(*)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list
          .map((item) => WishlistItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Checks if a product is in the customer's wishlist.
  Future<bool> isWishlisted(String productId) async {
    if (!isReady) return false;
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final res = await _effectiveClient
          .from('wishlists')
          .select('id')
          .eq('customer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Toggles wishlist status: removes if exists, adds if absent.
  /// Returns `true` if added, `false` if removed.
  Future<bool> toggleWishlist(String productId) async {
    if (!isReady) return false;
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final existing = await _effectiveClient
          .from('wishlists')
          .select('id')
          .eq('customer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        await _effectiveClient
            .from('wishlists')
            .delete()
            .eq('id', existing['id']);
        return false;
      } else {
        await _effectiveClient.from('wishlists').insert({
          'customer_id': userId,
          'product_id': productId,
        });
        return true;
      }
    } catch (_) {
      return false;
    }
  }
}
