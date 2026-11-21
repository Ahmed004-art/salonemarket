import 'package:flutter/foundation.dart';
import 'package:salonemarket/features/cart/data/models/cart_item_model.dart';
import 'package:salonemarket/features/cart/data/services/cart_storage_service.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';

/// Central state manager for customer cart interactions.
///
/// Tracks selected products, quantities, inventory ceilings, multi-vendor
/// grouping, and provides **user-scoped** local persistence across sessions.
///
/// ## User isolation (Finding 3 fix)
///
/// [CartNotifier] is now user-aware.  Call [setUser] after sign-in and
/// [clearUser] before sign-out so that:
/// - Authenticated users load and persist their own cart exclusively.
/// - Guest carts are stored separately under a distinct key.
/// - A different user signing in on the same device never sees the previous
///   user's cart items.
class CartNotifier extends ChangeNotifier {
  CartNotifier({
    CartStorageService? storageService,
    bool autoLoad = true,
  }) : _storageService = storageService ?? CartStorageService() {
    if (autoLoad) {
      _loadForCurrentUser();
    }
  }

  final CartStorageService _storageService;
  final Map<String, CartItem> _items = {};
  bool _isInitialized = false;
  String? _userId; // null = guest

  bool get isInitialized => _isInitialized;
  Map<String, CartItem> get items => Map.unmodifiable(_items);

  // ---------------------------------------------------------------------------
  // User lifecycle (Finding 3)
  // ---------------------------------------------------------------------------

  /// Call after a user successfully signs in.
  /// Clears the current in-memory cart and loads the user's persisted cart.
  /// The guest cart is NOT merged — that behaviour is a deliberate product
  /// decision to be implemented in a dedicated "merge guest cart" flow if needed.
  Future<void> setUser(String userId) async {
    if (_userId == userId) return; // already scoped to this user
    _userId = userId;
    _items.clear();
    _isInitialized = false;
    notifyListeners();
    await _loadForCurrentUser();
  }

  /// Call before a user signs out.
  /// Persists the current cart under the user key (preserves their items for
  /// the next login), then clears the in-memory cart so the next user (or
  /// guest session) starts clean.
  Future<void> clearUser() async {
    // Persist current state before wiping in-memory
    await _storageService.saveCart(_items.values.toList(), userId: _userId);
    _userId = null;
    _items.clear();
    _isInitialized = true; // guest state = initialized empty
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal persistence
  // ---------------------------------------------------------------------------

  /// Loads persisted cart items for the current user scope (guest if no user set).
  ///
  /// Called automatically on construction when [autoLoad] is true.
  /// Also available publicly for tests or explicit reload scenarios.
  Future<void> initialize() => _loadForCurrentUser();

  Future<void> _loadForCurrentUser() async {
    final loadedItems = await _storageService.loadCart(userId: _userId);
    if (loadedItems.isNotEmpty) {
      for (final item in loadedItems) {
        _items[item.product.id] = item;
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  void _persist() {
    _storageService.saveCart(_items.values.toList(), userId: _userId);
  }

  // ---------------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------------

  /// Total count of all individual units in the cart.
  int get itemCount =>
      _items.values.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Total count of distinct product lines in the cart.
  int get lineCount => _items.length;

  /// Combined total price for all items in the cart.
  double get subtotal =>
      _items.values.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

  /// Formatted subtotal: `SLE 450`.
  String get formattedSubtotal {
    if (subtotal == subtotal.roundToDouble()) {
      return 'SLE ${subtotal.toInt()}';
    }
    return 'SLE ${subtotal.toStringAsFixed(2)}';
  }

  /// Groups cart items by their merchant vendor ID.
  Map<String, List<CartItem>> get itemsByVendor {
    final Map<String, List<CartItem>> grouped = {};
    for (final item in _items.values) {
      final vendorId = item.product.vendorId;
      grouped.putIfAbsent(vendorId, () => []).add(item);
    }
    return grouped;
  }

  /// Items that are out of stock or where cart quantity exceeds available inventory.
  List<CartItem> get unavailableItems {
    return _items.values.where((item) {
      final product = item.product;
      if (!product.isInStock) return true;
      if (product.trackInventory && item.quantity > product.stockQuantity) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Whether the cart contains any currently unavailable items.
  bool get hasUnavailableItems => unavailableItems.isNotEmpty;

  /// Whether a specific product is already present in the cart.
  bool containsProduct(String productId) => _items.containsKey(productId);

  /// Current quantity of a specific product in the cart (0 if not present).
  int getQuantity(String productId) => _items[productId]?.quantity ?? 0;

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Adds a product to the cart with specified quantity (default 1).
  ///
  /// Returns `true` if item was added or incremented, or `false` if rejected
  /// due to out-of-stock condition or exceeding available inventory.
  bool addItem(Product product, {int quantity = 1}) {
    if (quantity <= 0) return false;
    if (!product.isInStock) return false;

    final maxStock = product.trackInventory ? product.stockQuantity : 99;
    if (maxStock <= 0) return false;

    if (_items.containsKey(product.id)) {
      final existing = _items[product.id]!;
      if (existing.quantity >= maxStock) {
        return false; // Already reached available stock ceiling
      }
      final newQuantity = (existing.quantity + quantity).clamp(1, maxStock);
      _items[product.id] = existing.copyWith(quantity: newQuantity);
    } else {
      final initialQuantity = quantity.clamp(1, maxStock);
      _items[product.id] = CartItem(
        product: product,
        quantity: initialQuantity,
        unitPrice: product.price,
      );
    }
    notifyListeners();
    _persist();
    return true;
  }

  /// Updates quantity of an existing item in the cart.
  /// Removes item if quantity <= 0. Clamps to available inventory.
  void updateQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;

    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      final existing = _items[productId]!;
      final maxStock = existing.product.trackInventory
          ? existing.product.stockQuantity
          : 99;
      final clamped = quantity.clamp(1, maxStock > 0 ? maxStock : 1);
      _items[productId] = existing.copyWith(quantity: clamped);
    }
    notifyListeners();
    _persist();
  }

  /// Removes an item completely from the cart.
  void removeItem(String productId) {
    if (_items.remove(productId) != null) {
      notifyListeners();
      _persist();
    }
  }

  /// Empties the entire in-memory cart and clears the persisted storage.
  void clear() {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
      _persist();
    }
  }
}
