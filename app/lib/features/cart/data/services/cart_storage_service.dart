import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';

/// Secure, reliable local persistence service for the customer shopping cart.
///
/// Stores non-sensitive item metadata (product id, name, unit price, quantity)
/// so that customers (both guest and authenticated) retain their cart
/// state across application reloads and navigation.
///
/// ## User isolation (Finding 3 fix)
///
/// Each user's cart is stored under a unique key derived from their user ID.
/// Guest carts use a separate `_guestKey`.  When a user logs in, their
/// previously-persisted user cart is loaded — the guest cart is not merged
/// automatically (the UI layer controls guest-to-login transition).
/// When a user logs out, loading with `userId: null` returns the guest cart
/// (or an empty cart if none exists), never the previous user's items.
class CartStorageService {
  CartStorageService({SharedPreferences? preferences})
      : _preferences = preferences;

  /// Storage key prefix for authenticated user carts.
  static const String _userKeyPrefix = 'salonemarket_cart_v2_user_';

  /// Storage key for the shared guest (unauthenticated) cart.
  static const String _guestKey = 'salonemarket_cart_v2_guest';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  /// Returns the storage key for the given [userId].
  /// If [userId] is null, returns the guest key.
  static String storageKey(String? userId) =>
      userId != null ? '$_userKeyPrefix$userId' : _guestKey;

  // ---------------------------------------------------------------------------
  // Core persistence operations (user-scoped)
  // ---------------------------------------------------------------------------

  /// Loads saved cart items for [userId] from local storage.
  /// Pass `null` for a guest (unauthenticated) session.
  Future<List<CartItem>> loadCart({String? userId}) async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(storageKey(userId));
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final List<CartItem> items = [];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          try {
            items.add(CartItem.fromMap(entry));
          } catch (_) {
            // Ignore malformed individual entries gracefully
          }
        }
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Persists the provided [items] under the key for [userId].
  /// Pass `null` for a guest (unauthenticated) session.
  Future<bool> saveCart(List<CartItem> items, {String? userId}) async {
    try {
      final prefs = await _prefs;
      final key = storageKey(userId);
      if (items.isEmpty) {
        return await prefs.remove(key);
      }
      final serialized = jsonEncode(items.map((item) => item.toMap()).toList());
      return await prefs.setString(key, serialized);
    } catch (_) {
      return false;
    }
  }

  /// Clears persisted cart storage for [userId].
  /// Pass `null` to clear the guest cart.
  Future<bool> clearCart({String? userId}) async {
    try {
      final prefs = await _prefs;
      return await prefs.remove(storageKey(userId));
    } catch (_) {
      return false;
    }
  }

  /// Clears BOTH the guest cart and the specified user cart.
  /// Used during account switching to guarantee no cross-user leakage.
  Future<void> clearAll({String? userId}) async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_guestKey);
      if (userId != null) {
        await prefs.remove(storageKey(userId));
      }
    } catch (_) {
      // Best-effort; non-fatal
    }
  }
}
