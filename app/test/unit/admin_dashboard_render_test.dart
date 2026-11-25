import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/admin/data/models/admin_stats_model.dart';
import 'package:salonemarket/features/admin/presentation/controllers/admin_notifier.dart';
import 'package:salonemarket/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:salonemarket/features/admin/presentation/screens/admin_vendors_screen.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';

class FakeAdminNotifier extends ChangeNotifier implements AdminNotifier {
  AdminStatusState _status = AdminStatusState.initial;
  AdminPlatformStats? _stats;
  String? _errorMessage;
  List<Map<String, dynamic>> _vendors = [];

  @override
  AdminStatusState get status => _status;
  @override
  bool get isLoading => _status == AdminStatusState.loading;
  @override
  AdminPlatformStats? get stats => _stats;
  @override
  String? get errorMessage => _errorMessage;

  @override
  String? get vendorsError => null;
  @override
  String? get productsError => null;
  @override
  String? get ordersError => null;
  @override
  String? get transactionsError => null;
  @override
  String? get usersError => null;

  @override
  bool get isVendorsLoading => false;
  @override
  bool get isProductsLoading => false;
  @override
  bool get isOrdersLoading => false;
  @override
  bool get isTransactionsLoading => false;
  @override
  bool get isUsersLoading => false;

  @override
  List<Map<String, dynamic>> get vendors => _vendors;
  @override
  List<Product> get products => [];
  @override
  List<Map<String, dynamic>> get orders => [];
  @override
  List<Map<String, dynamic>> get transactions => [];
  @override
  List<Map<String, dynamic>> get users => [];
  @override
  String get vendorFilter => 'all';
  @override
  String get productFilter => 'all';

  void setInitial() {
    _status = AdminStatusState.initial;
    _stats = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setLoading() {
    _status = AdminStatusState.loading;
    notifyListeners();
  }

  void setLoaded(AdminPlatformStats stats) {
    _status = AdminStatusState.loaded;
    _stats = stats;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    _status = AdminStatusState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void setVendors(List<Map<String, dynamic>> v) {
    _vendors = v;
    notifyListeners();
  }

  @override
  Future<void> loadDashboard() async {}
  @override
  Future<void> loadVendors({String? filter}) async {}
  @override
  Future<bool> updateVendorStatus(String vendorId, String newStatus,
          {double? commissionRate}) async =>
      true;
  @override
  Future<void> loadProducts({String? filter}) async {}
  @override
  Future<bool> updateProductStatus(String productId, String newStatus) async =>
      true;
  @override
  Future<void> loadOrders() async {}
  @override
  Future<void> loadTransactions() async {}
  @override
  Future<void> loadUsers() async {}
}

void main() {
  testWidgets(
    'AdminDashboardScreen renders all states with SaloneMarketTheme.lightTheme without layout/render errors',
    (tester) async {
      final notifier = FakeAdminNotifier();

      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: ChangeNotifierProvider<AdminNotifier>.value(
            value: notifier,
            child: const AdminDashboardScreen(),
          ),
        ),
      );

      // Initial state
      expect(find.text('Admin Operations Center'), findsOneWidget);
      expect(find.text('Administrative Modules'), findsOneWidget);
      expect(find.text('Vendor Management'), findsOneWidget);

      // Loading state
      notifier.setLoading();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Loaded state WITH pending vendors & reconciliation alerts
      notifier.setLoaded(AdminPlatformStats.fromMap({
        'total_customers': 1420,
        'total_vendors': 56,
        'pending_vendors': 4,
        'active_vendors': 50,
        'suspended_vendors': 2,
        'total_products': 480,
        'active_products': 430,
        'flagged_products': 5,
        'total_orders': 980,
        'total_gmv': 245000.00,
        'today_gmv': 3500.00,
        'week_gmv': 24000.00,
        'month_gmv': 98000.00,
        'reconciliation_alerts': 2,
      }));
      await tester.pump();

      expect(find.text('2 Payment Reconciliation Alert(s)'), findsOneWidget);
      expect(find.text('4 Pending Vendor Application(s)'), findsOneWidget);
      expect(find.text('Active Stores'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);

      // Error state
      notifier.setError('Access denied: Administrator privileges required');
      await tester.pump();
      expect(find.text('Access denied: Administrator privileges required'),
          findsOneWidget);
    },
  );

  testWidgets(
    'AdminVendorsScreen renders pending/active/suspended vendor action buttons with SaloneMarketTheme.lightTheme',
    (tester) async {
      final notifier = FakeAdminNotifier();
      notifier.setVendors([
        {
          'id': 'v1',
          'shop_name': 'Freetown Tech',
          'status': 'pending',
          'phone': '+23276000001',
          'location': 'Freetown',
          'commission_rate': 0.05,
          'profiles': {'full_name': 'Mohamed Kamara'},
        },
        {
          'id': 'v2',
          'shop_name': 'Bo Crafts',
          'status': 'active',
          'phone': '+23276000002',
          'location': 'Bo',
          'commission_rate': 0.05,
          'profiles': {'full_name': 'Aminata Sesay'},
        },
        {
          'id': 'v3',
          'shop_name': 'Kenema Goods',
          'status': 'suspended',
          'phone': '+23276000003',
          'location': 'Kenema',
          'commission_rate': 0.05,
          'profiles': {'full_name': 'Ibrahim Koroma'},
        },
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: ChangeNotifierProvider<AdminNotifier>.value(
            value: notifier,
            child: const AdminVendorsScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Approve Store'), findsOneWidget);
      expect(find.text('Suspend'), findsOneWidget);
      expect(find.text('Reactivate Store'), findsOneWidget);
    },
  );
}
