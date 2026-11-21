import 'package:flutter/foundation.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../data/models/checkout_result_model.dart';
import '../../data/repositories/checkout_repository.dart';

/// Central state manager for checkout preparation and order initiation.
class CheckoutNotifier extends ChangeNotifier {
  CheckoutNotifier({CheckoutRepository? repository})
      : _repository = repository ?? CheckoutRepository();

  final CheckoutRepository _repository;

  bool _isProcessing = false;
  String? _errorMessage;
  CheckoutResult? _lastResult;

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  CheckoutResult? get lastResult => _lastResult;

  /// Prepares and executes the authoritative checkout initialization.
  Future<bool> processCheckout({
    required List<CartItem> items,
    required String addressId,
    String? notes,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Sync cart to backend
    final synced = await _repository.syncCartToSupabase(items);
    if (!synced) {
      _errorMessage =
          'Could not synchronize cart items with backend. Please try again.';
      _isProcessing = false;
      notifyListeners();
      return false;
    }

    // 2. Call initiate-checkout Edge Function
    final result = await _repository.initiateCheckout(
      shippingAddressId: addressId,
      notes: notes,
    );

    _lastResult = result;
    if (result.isSuccess) {
      _errorMessage = null;
      _isProcessing = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Checkout preparation failed.';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _isProcessing = false;
    _errorMessage = null;
    _lastResult = null;
    notifyListeners();
  }
}
