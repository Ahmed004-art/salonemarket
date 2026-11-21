import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/checkout/data/models/checkout_result_model.dart';
import 'package:salonemarket/features/checkout/data/repositories/checkout_repository.dart';

void main() {
  group('CheckoutResult Model Tests', () {
    test('fromMap parses successful backend response', () {
      final map = {
        'success': true,
        'customer_order_id': 'cord-101',
        'vendor_order_ids': ['vord-1', 'vord-2'],
        'total': 1850.50,
      };

      final result = CheckoutResult.fromMap(map);

      expect(result.isSuccess, isTrue);
      expect(result.customerOrderId, equals('cord-101'));
      expect(result.vendorOrderIds, equals(['vord-1', 'vord-2']));
      expect(result.total, equals(1850.50));
      expect(result.formattedTotal, equals('SLE 1850.50'));
      expect(result.errorMessage, isNull);
    });

    test('fromMap parses failure response with error string', () {
      final map = {
        'success': false,
        'error': 'Insufficient stock for "Tecno Spark 20 Pro"',
      };

      final result = CheckoutResult.fromMap(map);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, equals('Insufficient stock for "Tecno Spark 20 Pro"'));
      expect(result.customerOrderId, isNull);
    });

    test('failure constructor initializes cleanly', () {
      final result = CheckoutResult.failure('Backend timeout');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, equals('Backend timeout'));
      expect(result.total, equals(0.0));
    });
  });

  group('CheckoutRepository Base Behavior Tests', () {
    late CheckoutRepository repository;

    setUp(() {
      repository = CheckoutRepository();
    });

    test('isReady is false when Supabase is not configured', () {
      expect(repository.isReady, isFalse);
    });

    test('syncCartToSupabase returns false when unconfigured', () async {
      final synced = await repository.syncCartToSupabase([]);
      expect(synced, isFalse);
    });

    test('initiateCheckout returns failure when unconfigured', () async {
      final result = await repository.initiateCheckout(
        shippingAddressId: 'addr-1',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('not configured'));
    });
  });
}
