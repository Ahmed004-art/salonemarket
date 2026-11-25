import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../../../marketplace/data/models/product_model.dart';
import '../../../marketplace/data/models/vendor_model.dart';
import '../../data/models/vendor_dashboard_stats.dart';
import '../../data/models/vendor_order_model.dart';
import '../../data/repositories/vendor_repository.dart';

enum VendorStatusState { initial, loading, loaded, error }

class VendorNotifier extends ChangeNotifier {
  VendorNotifier({VendorRepository? repository})
      : _repository = repository ?? VendorRepository();

  final VendorRepository _repository;

  VendorStatusState _status = VendorStatusState.initial;
  Vendor? _vendorStore;
  VendorDashboardStats? _dashboardStats;
  List<Product> _products = [];
  List<VendorOrder> _orders = [];
  VendorOrder? _currentOrder;
  String? _errorMessage;
  String _orderFilter = 'all';

  // Getters
  VendorStatusState get status => _status;
  bool get isLoading => _status == VendorStatusState.loading;
  Vendor? get vendorStore => _vendorStore;
  Vendor? get vendor => _vendorStore;
  VendorDashboardStats? get dashboardStats => _dashboardStats;
  List<Product> get products => _products;
  List<VendorOrder> get orders => _orders;
  VendorOrder? get currentOrder => _currentOrder;
  String? get errorMessage => _errorMessage;
  String get orderFilter => _orderFilter;

  bool get isApproved => _vendorStore?.status == 'active';
  bool get isPending => _vendorStore?.status == 'pending';
  bool get isSuspended => _vendorStore?.status == 'suspended';
  bool get hasStore => _vendorStore != null;

  /// Loads the active vendor profile and initial dashboard data
  Future<void> loadVendorProfile() async {
    _status = VendorStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _vendorStore = await _repository.getMyVendorStore();
      if (_vendorStore != null && _vendorStore!.status == 'active') {
        _dashboardStats = await _repository.getDashboardStats(_vendorStore!.id);
      }
      _status = VendorStatusState.loaded;
    } catch (e) {
      _status = VendorStatusState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Refreshes dashboard statistics
  Future<void> refreshDashboard() async {
    if (_vendorStore == null) return;
    try {
      _dashboardStats = await _repository.getDashboardStats(_vendorStore!.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing vendor dashboard: $e');
    }
  }

  /// Submits application for a new vendor store
  Future<bool> applyForVendor({
    required String shopName,
    required String slug,
    String? description,
    String? phone,
    String? location,
    String? email,
  }) async {
    _status = VendorStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.applyForVendor(
        shopName: shopName,
        slug: slug,
        description: description,
        phone: phone,
        location: location,
        email: email,
      );

      // Re-fetch store
      _vendorStore = await _repository.getMyVendorStore();
      _status = VendorStatusState.loaded;
      notifyListeners();
      return res['success'] == true;
    } catch (e) {
      _status = VendorStatusState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads products for this vendor
  Future<void> loadProducts() async {
    if (_vendorStore == null) return;
    _status = VendorStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _repository.getVendorProducts(_vendorStore!.id);
      _status = VendorStatusState.loaded;
    } catch (e) {
      _status = VendorStatusState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Saves or creates a product
  Future<bool> saveProduct({
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
    if (_vendorStore == null) return false;
    try {
      final res = await _repository.saveProduct(
        vendorId: _vendorStore!.id,
        productId: productId,
        name: name,
        description: description,
        price: price,
        compareAtPrice: compareAtPrice,
        costPrice: costPrice,
        stockQuantity: stockQuantity,
        categoryId: categoryId,
        sku: sku,
        status: status,
        imageUrl: imageUrl,
      );

      await loadProducts();
      await refreshDashboard();
      return res['success'] == true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Uploads product image
  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    if (_vendorStore == null) return null;
    try {
      return await _repository.uploadProductImage(
        vendorId: _vendorStore!.id,
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Deactivates product
  Future<bool> deactivateProduct(String productId) async {
    if (_vendorStore == null) return false;
    try {
      await _repository.deactivateProduct(_vendorStore!.id, productId);
      await loadProducts();
      await refreshDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads vendor orders
  Future<void> loadOrders({String? status}) async {
    if (_vendorStore == null) return;
    _status = VendorStatusState.loading;
    _errorMessage = null;
    if (status != null) _orderFilter = status;
    notifyListeners();

    try {
      _orders = await _repository.getVendorOrders(_vendorStore!.id, statusFilter: _orderFilter);
      _status = VendorStatusState.loaded;
    } catch (e) {
      _status = VendorStatusState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Loads a single order detail
  Future<void> loadOrderDetail(String vendorOrderId) async {
    _status = VendorStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentOrder = await _repository.getVendorOrderDetail(vendorOrderId);
      _status = VendorStatusState.loaded;
    } catch (e) {
      _status = VendorStatusState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Updates an order fulfillment status
  Future<bool> updateOrderStatus(String vendorOrderId, String newStatus, {String? notes}) async {
    try {
      final res = await _repository.updateOrderStatus(
        vendorOrderId: vendorOrderId,
        newStatus: newStatus,
        notes: notes,
      );

      // Refresh current order and order list
      await loadOrderDetail(vendorOrderId);
      await loadOrders();
      await refreshDashboard();
      return res['success'] == true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
