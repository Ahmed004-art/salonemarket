import 'package:flutter/foundation.dart';
import '../../data/models/wishlist_item_model.dart';
import '../../data/repositories/wishlist_repository.dart';

class WishlistNotifier extends ChangeNotifier {
  WishlistNotifier({WishlistRepository? repository})
      : _repository = repository ?? WishlistRepository();

  final WishlistRepository _repository;

  List<WishlistItem> _items = [];
  final Set<String> _wishlistedProductIds = {};
  bool _isLoading = false;

  List<WishlistItem> get items => _items;
  Set<String> get wishlistedProductIds => _wishlistedProductIds;
  bool get isLoading => _isLoading;

  bool isProductWishlisted(String productId) =>
      _wishlistedProductIds.contains(productId);

  Future<void> loadWishlist() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _repository.getWishlist();
      _wishlistedProductIds.clear();
      for (final item in _items) {
        _wishlistedProductIds.add(item.productId);
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleWishlist(String productId) async {
    final added = await _repository.toggleWishlist(productId);
    if (added) {
      _wishlistedProductIds.add(productId);
    } else {
      _wishlistedProductIds.remove(productId);
      _items.removeWhere((item) => item.productId == productId);
    }
    notifyListeners();
    return added;
  }
}
