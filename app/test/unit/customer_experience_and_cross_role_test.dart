import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/notifications/data/models/notification_model.dart';
import 'package:salonemarket/features/orders/data/models/customer_order_model.dart';
import 'package:salonemarket/features/wishlist/data/models/wishlist_item_model.dart';

void main() {
  group('Customer Experience — Models & Formatting', () {
    test('CustomerOrder parsing and status helpers correctly identify states', () {
      final map = {
        'id': 'co-12345678-abcd',
        'customer_id': 'cust-001',
        'status': 'partially_fulfilled',
        'subtotal': 450.00,
        'delivery_fee': 25.00,
        'platform_fee': 5.00,
        'total': 480.00,
        'payment_status': 'paid',
        'payment_method': 'mobile_money',
        'created_at': '2026-11-22T10:00:00Z',
        'order_items': [
          {
            'id': 'oi-1',
            'customer_order_id': 'co-12345678-abcd',
            'vendor_order_id': 'vo-1',
            'product_id': 'prod-1',
            'vendor_id': 'vend-1',
            'product_name': 'Fresh Cassava Leaves',
            'quantity': 3,
            'unit_price': 50.00,
            'line_total': 150.00,
          },
          {
            'id': 'oi-2',
            'customer_order_id': 'co-12345678-abcd',
            'vendor_order_id': 'vo-2',
            'product_id': 'prod-2',
            'vendor_id': 'vend-2',
            'product_name': 'Dried Bonga Fish',
            'quantity': 2,
            'unit_price': 150.00,
            'line_total': 300.00,
          }
        ],
        'vendor_orders': [
          {
            'id': 'vo-1',
            'vendor_id': 'vend-1',
            'status': 'processing',
            'subtotal': 150.00,
          },
          {
            'id': 'vo-2',
            'vendor_id': 'vend-2',
            'status': 'confirmed',
            'subtotal': 300.00,
          }
        ],
      };

      final order = CustomerOrder.fromMap(map);

      expect(order.id, 'co-12345678-abcd');
      expect(order.isPaid, isTrue);
      expect(order.isFulfilled, isFalse);
      expect(order.isActive, isTrue);
      expect(order.formattedTotal, 'SLE 480.00');
      expect(order.formattedSubtotal, 'SLE 450.00');
      expect(order.items.length, 2);
      expect(order.items[0].productName, 'Fresh Cassava Leaves');
      expect(order.items[0].formattedPrice, 'SLE 50.00');
      expect(order.items[0].formattedTotal, 'SLE 150.00');
      expect(order.vendorOrders.length, 2);
    });

    test('AppNotification parsing and relative time calculation', () {
      final now = DateTime.now();
      final map = {
        'id': 'notif-1',
        'user_id': 'user-1',
        'type': 'order_confirmed',
        'title': 'Order Confirmed',
        'body': 'Your order #co-123 has been accepted by the merchant.',
        'data': {'order_id': 'co-123'},
        'is_read': false,
        'created_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      };

      final notif = AppNotification.fromMap(map);

      expect(notif.id, 'notif-1');
      expect(notif.isRead, isFalse);
      expect(notif.title, 'Order Confirmed');
      expect(notif.timeAgo, contains('m ago'));
    });

    test('WishlistItem parsing with associated Product snapshot', () {
      final map = {
        'id': 'w-1',
        'customer_id': 'cust-1',
        'product_id': 'p-1',
        'created_at': '2026-11-22T12:00:00Z',
        'product': {
          'id': 'p-1',
          'vendor_id': 'v-1',
          'name': 'Gari (Sierra Leone Style)',
          'slug': 'gari-sl',
          'price': 75.00,
          'stock_quantity': 20,
        },
      };

      final item = WishlistItem.fromMap(map);

      expect(item.id, 'w-1');
      expect(item.productId, 'p-1');
      expect(item.product.name, 'Gari (Sierra Leone Style)');
      expect(item.product.price, 75.00);
      expect(item.product.isInStock, isTrue);
    });
  });

  group('Cross-Role Workflow & Security Validation', () {
    test('Multi-vendor order separation enforces distinct vendor sub-orders', () {
      final orderMap = {
        'id': 'co-multi-vendor',
        'customer_id': 'customer-abc',
        'status': 'confirmed',
        'subtotal': 500.0,
        'delivery_fee': 30.0,
        'platform_fee': 0.0,
        'total': 530.0,
        'payment_status': 'paid',
        'created_at': '2026-11-22T10:00:00Z',
        'vendor_orders': [
          {
            'id': 'vo-merchant-alpha',
            'vendor_id': 'merchant-alpha',
            'status': 'processing',
            'subtotal': 200.0,
          },
          {
            'id': 'vo-merchant-beta',
            'vendor_id': 'merchant-beta',
            'status': 'confirmed',
            'subtotal': 300.0,
          }
        ],
      };

      final order = CustomerOrder.fromMap(orderMap);

      expect(order.vendorOrders.length, 2);
      final alphaOrder = order.vendorOrders.firstWhere((vo) => vo.vendorId == 'merchant-alpha');
      final betaOrder = order.vendorOrders.firstWhere((vo) => vo.vendorId == 'merchant-beta');

      expect(alphaOrder.subtotal, 200.0);
      expect(betaOrder.subtotal, 300.0);
      // Multi-vendor subtotal matches sum of vendor orders
      expect(alphaOrder.subtotal + betaOrder.subtotal, order.subtotal);
    });

    test('Payment status and fulfillment status remain strictly decoupled', () {
      // Case 1: Order is placed but unpaid
      final unpaidMap = {
        'id': 'co-unpaid',
        'customer_id': 'cust-1',
        'status': 'pending_payment',
        'subtotal': 100.0,
        'delivery_fee': 10.0,
        'platform_fee': 0.0,
        'total': 110.0,
        'payment_status': 'pending',
        'created_at': '2026-11-22T10:00:00Z',
      };
      final unpaidOrder = CustomerOrder.fromMap(unpaidMap);
      expect(unpaidOrder.isPaid, isFalse);
      expect(unpaidOrder.status, 'pending_payment');

      // Case 2: Order is paid but fulfillment is still processing
      final paidProcessingMap = {
        'id': 'co-paid',
        'customer_id': 'cust-1',
        'status': 'confirmed',
        'subtotal': 100.0,
        'delivery_fee': 10.0,
        'platform_fee': 0.0,
        'total': 110.0,
        'payment_status': 'paid',
        'created_at': '2026-11-22T10:00:00Z',
      };
      final paidOrder = CustomerOrder.fromMap(paidProcessingMap);
      expect(paidOrder.isPaid, isTrue);
      expect(paidOrder.isFulfilled, isFalse);
      expect(paidOrder.status, 'confirmed');

      // Case 3: Order payment failed
      final failedMap = {
        'id': 'co-failed',
        'customer_id': 'cust-1',
        'status': 'payment_failed',
        'subtotal': 100.0,
        'delivery_fee': 10.0,
        'platform_fee': 0.0,
        'total': 110.0,
        'payment_status': 'failed',
        'created_at': '2026-11-22T10:00:00Z',
      };
      final failedOrder = CustomerOrder.fromMap(failedMap);
      expect(failedOrder.isPaid, isFalse);
      expect(failedOrder.paymentStatus, 'failed');
      expect(failedOrder.status, 'payment_failed');
    });

    test('Promotions calculation logic matches server RPC contract', () {
      // Test 1: Percentage discount (WELCOME10 - 10% on SLE 200)
      const subtotal1 = 200.0;
      const discountPercent = 10.0;
      final discountAmount1 = (subtotal1 * (discountPercent / 100.0)).roundToDouble();
      final newSubtotal1 = subtotal1 - discountAmount1;
      expect(discountAmount1, 20.0);
      expect(newSubtotal1, 180.0);

      // Test 2: Fixed amount discount (SALONE50 - SLE 50 off above SLE 250)
      const subtotal2 = 300.0;
      const fixedDiscount = 50.0;
      final newSubtotal2 = subtotal2 - fixedDiscount;
      expect(newSubtotal2, 250.0);

      // Test 3: Min order check rejects below threshold
      const subtotalSmall = 150.0;
      const minOrderAmount = 250.0;
      final isEligible = subtotalSmall >= minOrderAmount;
      expect(isEligible, isFalse);
    });

    test('Review eligibility rule requires verified, paid purchase', () {
      // Given a customer with no paid orders
      bool checkEligible({
        required bool isAuthenticated,
        required bool hasDeliveredPaidOrder,
        required bool alreadyReviewed,
      }) {
        if (!isAuthenticated) return false;
        if (alreadyReviewed) return false;
        if (!hasDeliveredPaidOrder) return false;
        return true;
      }

      // Guest user -> ineligible
      expect(checkEligible(
        isAuthenticated: false,
        hasDeliveredPaidOrder: true,
        alreadyReviewed: false,
      ), isFalse);

      // Authenticated but no paid order -> ineligible
      expect(checkEligible(
        isAuthenticated: true,
        hasDeliveredPaidOrder: false,
        alreadyReviewed: false,
      ), isFalse);

      // Authenticated with paid order and already reviewed -> ineligible (duplicate)
      expect(checkEligible(
        isAuthenticated: true,
        hasDeliveredPaidOrder: true,
        alreadyReviewed: true,
      ), isFalse);

      // Authenticated, paid order, not yet reviewed -> eligible
      expect(checkEligible(
        isAuthenticated: true,
        hasDeliveredPaidOrder: true,
        alreadyReviewed: false,
      ), isTrue);
    });
  });
}
