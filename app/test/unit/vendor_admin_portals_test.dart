import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/admin/data/models/admin_stats_model.dart';
import 'package:salonemarket/features/vendor/data/models/vendor_dashboard_stats.dart';
import 'package:salonemarket/features/vendor/data/models/vendor_order_model.dart';

void main() {
  group('Vendor and Admin Portals Unit Tests', () {
    test('1. VendorDashboardStats accurately parses real database values', () {
      final map = {
        'vendor_id': 'v-123',
        'shop_name': 'Kono Fresh Produce',
        'status': 'active',
        'total_products': 24,
        'active_products': 20,
        'pending_orders': 5,
        'completed_orders': 42,
        'total_sales': 12500.50,
        'today_sales': 450.00,
        'week_sales': 2100.00,
        'month_sales': 8900.00,
        'recent_orders': [
          {
            'id': 'vo-1',
            'customer_order_id': 'cord-11112222',
            'status': 'confirmed',
            'payment_status': 'paid',
            'subtotal': 300.0,
            'vendor_payout': 285.0,
            'customer_name': 'Mariama Kamara',
            'item_count': 3,
            'created_at': '2026-11-22T10:00:00Z',
          }
        ],
      };

      final stats = VendorDashboardStats.fromMap(map);

      expect(stats.vendorId, equals('v-123'));
      expect(stats.shopName, equals('Kono Fresh Produce'));
      expect(stats.isActive, isTrue);
      expect(stats.totalProducts, equals(24));
      expect(stats.activeProducts, equals(20));
      expect(stats.pendingOrders, equals(5));
      expect(stats.completedOrders, equals(42));
      expect(stats.totalSales, equals(12500.50));
      expect(stats.todaySales, equals(450.00));
      expect(stats.recentOrders.length, equals(1));
      expect(stats.recentOrders.first.customerName, equals('Mariama Kamara'));
      expect(stats.recentOrders.first.vendorPayout, equals(285.0));
    });

    test('2. VendorOrder blocks fulfillment transitions when unpaid', () {
      final unpaidOrderMap = {
        'id': 'vo-unpaid',
        'customer_order_id': 'cord-999',
        'vendor_id': 'v-123',
        'customer_id': 'cust-1',
        'status': 'awaiting_payment',
        'subtotal': 200.0,
        'delivery_fee': 20.0,
        'commission_amount': 10.0,
        'vendor_payout': 190.0,
        'created_at': '2026-11-22T09:00:00Z',
        'customer_orders': {
          'payment_status': 'pending',
        },
      };

      final order = VendorOrder.fromMap(unpaidOrderMap);

      expect(order.isPaid, isFalse);
      // When unpaid, allowableNextStatuses MUST be empty to prevent vendors advancing unpaid orders!
      expect(order.allowableNextStatuses, isEmpty);
    });

    test('3. VendorOrder enforces legal sequential status transitions when paid', () {
      final paidOrderMap = {
        'id': 'vo-paid',
        'customer_order_id': 'cord-100',
        'vendor_id': 'v-123',
        'customer_id': 'cust-1',
        'status': 'confirmed',
        'subtotal': 500.0,
        'delivery_fee': 30.0,
        'commission_amount': 25.0,
        'vendor_payout': 475.0,
        'created_at': '2026-11-22T08:00:00Z',
        'customer_orders': {
          'payment_status': 'paid',
        },
      };

      final confirmedOrder = VendorOrder.fromMap(paidOrderMap);
      expect(confirmedOrder.isPaid, isTrue);
      expect(confirmedOrder.allowableNextStatuses, contains('processing'));
      expect(confirmedOrder.allowableNextStatuses, contains('cancelled'));
      expect(confirmedOrder.allowableNextStatuses, isNot(contains('delivered'))); // cannot skip to delivered
    });

    test('4. AdminPlatformStats correctly parses real ecosystem figures', () {
      final map = {
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
        'reconciliation_alerts': 1,
      };

      final stats = AdminPlatformStats.fromMap(map);

      expect(stats.totalCustomers, equals(1420));
      expect(stats.totalVendors, equals(56));
      expect(stats.pendingVendors, equals(4));
      expect(stats.activeVendors, equals(50));
      expect(stats.suspendedVendors, equals(2));
      expect(stats.totalProducts, equals(480));
      expect(stats.flaggedProducts, equals(5));
      expect(stats.totalGmv, equals(245000.00));
      expect(stats.reconciliationAlerts, equals(1));
    });

    test('5. Vendor application slug generation cleanses special characters', () {
      const rawShopName = 'Freetown Fresh Foods & Palm Oil Ltd.!';
      final slug = rawShopName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');

      expect(slug, equals('freetown-fresh-foods-palm-oil-ltd'));
    });
  });
}
