import 'package:flutter/foundation.dart';
import '../../data/models/admin_stats_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../marketplace/data/models/product_model.dart';

enum AdminStatusState { initial, loading, loaded, error }

class AdminNotifier extends ChangeNotifier {
  AdminNotifier({AdminRepository? repository})
      : _repository = repository ?? AdminRepository();

  final AdminRepository _repository;

  // ── Separate status per data-domain ──────────────────────────────────────
  // Using a single shared _status was the root cause of the blank screen:
  // when loadDashboard() errored, every other screen reading isLoading/status
  // also saw the error state, destroying their content.
  AdminStatusState _dashboardStatus = AdminStatusState.initial;
  AdminStatusState _vendorsStatus = AdminStatusState.initial;
  AdminStatusState _productsStatus = AdminStatusState.initial;
  AdminStatusState _ordersStatus = AdminStatusState.initial;
  AdminStatusState _transactionsStatus = AdminStatusState.initial;
  AdminStatusState _usersStatus = AdminStatusState.initial;

  AdminPlatformStats? _stats;
  List<Map<String, dynamic>> _vendors = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _users = [];

  String? _dashboardError;
  String? _vendorsError;
  String? _productsError;
  String? _ordersError;
  String? _transactionsError;
  String? _usersError;

  // ── Getters ───────────────────────────────────────────────────────────────
  // isLoading / status return dashboard status to maintain backward compat
  // for the main dashboard screen.
  AdminStatusState get status => _dashboardStatus;
  bool get isLoading => _dashboardStatus == AdminStatusState.loading;

  AdminPlatformStats? get stats => _stats;
  List<Map<String, dynamic>> get vendors => _vendors;
  List<Product> get products => _products;
  List<Map<String, dynamic>> get orders => _orders;
  List<Map<String, dynamic>> get transactions => _transactions;
  List<Map<String, dynamic>> get users => _users;

  // errorMessage reflects dashboard error for backward compat
  String? get errorMessage => _dashboardError;

  // Per-domain error getters (for sub-screens to display their own errors)
  String? get vendorsError => _vendorsError;
  String? get productsError => _productsError;
  String? get ordersError => _ordersError;
  String? get transactionsError => _transactionsError;
  String? get usersError => _usersError;

  bool get isVendorsLoading => _vendorsStatus == AdminStatusState.loading;
  bool get isProductsLoading => _productsStatus == AdminStatusState.loading;
  bool get isOrdersLoading => _ordersStatus == AdminStatusState.loading;
  bool get isTransactionsLoading => _transactionsStatus == AdminStatusState.loading;
  bool get isUsersLoading => _usersStatus == AdminStatusState.loading;

  // Legacy vendorFilter / productFilter
  String _vendorFilter = 'all';
  String _productFilter = 'all';
  String get vendorFilter => _vendorFilter;
  String get productFilter => _productFilter;

  /// Loads platform dashboard statistics.
  /// Uses a SEPARATE status so a failing stats RPC does NOT kill other screens.
  Future<void> loadDashboard() async {
    _dashboardStatus = AdminStatusState.loading;
    _dashboardError = null;
    notifyListeners();

    try {
      _stats = await _repository.getPlatformStats();
      _dashboardStatus = AdminStatusState.loaded;
    } catch (e) {
      _dashboardStatus = AdminStatusState.error;
      _dashboardError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadDashboard] $e');
    }
    notifyListeners();
  }

  /// Loads vendors with optional filter
  Future<void> loadVendors({String? filter}) async {
    _vendorsStatus = AdminStatusState.loading;
    _vendorsError = null;
    if (filter != null) _vendorFilter = filter;
    notifyListeners();

    try {
      _vendors = await _repository.getVendors(statusFilter: _vendorFilter);
      _vendorsStatus = AdminStatusState.loaded;
    } catch (e) {
      _vendorsStatus = AdminStatusState.error;
      _vendorsError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadVendors] $e');
    }
    notifyListeners();
  }

  /// Approves or suspends a vendor
  Future<bool> updateVendorStatus(String vendorId, String newStatus, {double? commissionRate}) async {
    try {
      final res = await _repository.updateVendorStatus(
        vendorId: vendorId,
        status: newStatus,
        commissionRate: commissionRate,
      );

      await loadVendors();
      await loadDashboard();
      return res['success'] == true;
    } catch (e) {
      _vendorsError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads products platform-wide for moderation
  Future<void> loadProducts({String? filter}) async {
    _productsStatus = AdminStatusState.loading;
    _productsError = null;
    if (filter != null) _productFilter = filter;
    notifyListeners();

    try {
      _products = await _repository.getProducts(statusFilter: _productFilter);
      _productsStatus = AdminStatusState.loaded;
    } catch (e) {
      _productsStatus = AdminStatusState.error;
      _productsError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadProducts] $e');
    }
    notifyListeners();
  }

  /// Moderates product status (active, flagged, inactive)
  Future<bool> updateProductStatus(String productId, String newStatus) async {
    try {
      final res = await _repository.updateProductStatus(
        productId: productId,
        status: newStatus,
      );

      await loadProducts();
      await loadDashboard();
      return res['success'] == true;
    } catch (e) {
      _productsError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads platform orders
  Future<void> loadOrders() async {
    _ordersStatus = AdminStatusState.loading;
    _ordersError = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrders();
      _ordersStatus = AdminStatusState.loaded;
    } catch (e) {
      _ordersStatus = AdminStatusState.error;
      _ordersError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadOrders] $e');
    }
    notifyListeners();
  }

  /// Loads platform transactions
  Future<void> loadTransactions() async {
    _transactionsStatus = AdminStatusState.loading;
    _transactionsError = null;
    notifyListeners();

    try {
      _transactions = await _repository.getTransactions();
      _transactionsStatus = AdminStatusState.loaded;
    } catch (e) {
      _transactionsStatus = AdminStatusState.error;
      _transactionsError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadTransactions] $e');
    }
    notifyListeners();
  }

  /// Loads registered users
  Future<void> loadUsers() async {
    _usersStatus = AdminStatusState.loading;
    _usersError = null;
    notifyListeners();

    try {
      _users = await _repository.getUsers();
      _usersStatus = AdminStatusState.loaded;
    } catch (e) {
      _usersStatus = AdminStatusState.error;
      _usersError = e.toString();
      debugPrint('🚨 [AdminNotifier.loadUsers] $e');
    }
    notifyListeners();
  }
}
