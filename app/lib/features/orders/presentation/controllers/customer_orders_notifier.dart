import 'package:flutter/foundation.dart';
import '../../data/models/customer_order_model.dart';
import '../../data/repositories/customer_orders_repository.dart';

class CustomerOrdersNotifier extends ChangeNotifier {
  CustomerOrdersNotifier({CustomerOrdersRepository? repository})
      : _repository = repository ?? CustomerOrdersRepository();

  final CustomerOrdersRepository _repository;

  List<CustomerOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentFilter = 'all';

  List<CustomerOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  Future<void> loadOrders({String? filter}) async {
    if (filter != null) {
      _currentFilter = filter;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrders(statusFilter: _currentFilter);
    } catch (e) {
      _errorMessage = 'Failed to load order history.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    if (_currentFilter == filter) return;
    loadOrders(filter: filter);
  }
}
