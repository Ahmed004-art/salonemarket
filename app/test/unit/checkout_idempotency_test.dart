// Tests for checkout idempotency (Milestone 3 Final Security Audit — Section 1).
//
// These are CONTRACT / UNIT tests that verify:
//   • CheckoutResult correctly parses idempotency-related fields from the
//     server response (idempotency_key, idempotent_replay).
//   • CheckoutRepository.initiateCheckout accepts and forwards idempotency_key.
//   • A simulated idempotent-replay response is handled without error.
//   • A simulated duplicate request (same key, different attempt) returns the
//     original order ID, not a new one.
//
// DATABASE-LAYER TESTS (require live PostgreSQL + Supabase):
//   • RPC call with key that already exists → returns stored result, no new row
//   • Concurrent calls with same key → exactly one order created
//   • Expired key (> 24 h) → treated as absent, new order created
//   These tests are skipped in unit CI and annotated below.
//
// NOTE: All tests in this file are pure Dart unit tests (no DB, no network).

import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/checkout/data/models/checkout_result_model.dart';
import 'package:salonemarket/features/checkout/data/repositories/checkout_repository.dart';

// ---------------------------------------------------------------------------
// Helpers that mirror server response shapes
// ---------------------------------------------------------------------------

/// Simulates the server response for a fresh (first) checkout.
Map<String, dynamic> _freshOrderResponse({
  required String customerOrderId,
  required String idempotencyKey,
  List<String> vendorOrderIds = const ['vord-1'],
  double total = 2000.0,
}) =>
    {
      'success': true,
      'customer_order_id': customerOrderId,
      'vendor_order_ids': vendorOrderIds,
      'total': total,
      'idempotency_key': idempotencyKey,
    };

/// Simulates the server response for an idempotent replay (duplicate request
/// with the same key — the server returned the original order result).
Map<String, dynamic> _replayResponse({
  required String customerOrderId,
  required String idempotencyKey,
  List<String> vendorOrderIds = const ['vord-1'],
  double total = 2000.0,
}) =>
    {
      'success': true,
      'customer_order_id': customerOrderId,
      'vendor_order_ids': vendorOrderIds,
      'total': total,
      'idempotency_key': idempotencyKey,
      'idempotent_replay': true,
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Section 1 — CheckoutResult model: idempotency field parsing
  // =========================================================================
  group('CheckoutResult — idempotency field parsing', () {
    test(
        'fromMap parses idempotency_key from fresh order response', () {
      const key = '550e8400-e29b-41d4-a716-446655440000';
      final result = CheckoutResult.fromMap(
        _freshOrderResponse(customerOrderId: 'ord-001', idempotencyKey: key),
      );

      expect(result.isSuccess, isTrue);
      expect(result.customerOrderId, equals('ord-001'));
      expect(result.idempotencyKey, equals(key));
      expect(result.isIdempotentReplay, isFalse);
      expect(result.total, equals(2000.0));
    });

    test(
        'fromMap parses idempotent_replay flag from replay response', () {
      const key = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';
      final result = CheckoutResult.fromMap(
        _replayResponse(customerOrderId: 'ord-001', idempotencyKey: key),
      );

      expect(result.isSuccess, isTrue);
      // Same order ID returned — not a new one
      expect(result.customerOrderId, equals('ord-001'));
      expect(result.idempotencyKey, equals(key));
      expect(result.isIdempotentReplay, isTrue);
    });

    test(
        'replay result has the same customer_order_id as the original', () {
      const key = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';

      final firstResult = CheckoutResult.fromMap(
        _freshOrderResponse(customerOrderId: 'ord-002', idempotencyKey: key),
      );
      final replayResult = CheckoutResult.fromMap(
        _replayResponse(customerOrderId: 'ord-002', idempotencyKey: key),
      );

      // Both responses reference the same order
      expect(firstResult.customerOrderId, equals(replayResult.customerOrderId));
      expect(firstResult.isIdempotentReplay, isFalse);
      expect(replayResult.isIdempotentReplay, isTrue);
    });

    test(
        'fromMap: response without idempotency fields is still valid', () {
      // Older responses (or responses from the 5-argument RPC) don't have
      // the idempotency fields; the model must handle this gracefully.
      final result = CheckoutResult.fromMap({
        'success': true,
        'customer_order_id': 'ord-003',
        'vendor_order_ids': <String>[],
        'total': 500.0,
      });

      expect(result.isSuccess, isTrue);
      expect(result.idempotencyKey, isNull);
      expect(result.isIdempotentReplay, isFalse);
    });

    test(
        'fromMap: failure response does not set idempotency fields', () {
      final result = CheckoutResult.fromMap({
        'success': false,
        'error': 'Insufficient stock for "Rice"',
      });

      expect(result.isSuccess, isFalse);
      expect(result.idempotencyKey, isNull);
      expect(result.isIdempotentReplay, isFalse);
    });

    test(
        'failure constructor does not set idempotency fields', () {
      final result = CheckoutResult.failure('Network timeout');

      expect(result.isSuccess, isFalse);
      expect(result.idempotencyKey, isNull);
      expect(result.isIdempotentReplay, isFalse);
    });

    test(
        'formattedTotal is correct on replay result', () {
      final result = CheckoutResult.fromMap(
        _replayResponse(
          customerOrderId: 'ord-004',
          idempotencyKey: '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
          total: 3500.75,
        ),
      );
      expect(result.formattedTotal, equals('SLE 3500.75'));
    });

    test(
        'vendor_order_ids preserved correctly in replay', () {
      final result = CheckoutResult.fromMap(
        _replayResponse(
          customerOrderId: 'ord-005',
          idempotencyKey: '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
          vendorOrderIds: ['vord-A', 'vord-B'],
        ),
      );
      expect(result.vendorOrderIds, equals(['vord-A', 'vord-B']));
    });
  });

  // =========================================================================
  // Section 2 — CheckoutRepository: idempotency_key forwarding contract
  // =========================================================================
  group('CheckoutRepository — idempotencyKey parameter', () {
    late CheckoutRepository repository;

    setUp(() {
      repository = CheckoutRepository();
    });

    test(
        'initiateCheckout accepts optional idempotencyKey (Supabase not configured)', () async {
      // Verifies the new parameter is part of the method signature and that the
      // "not configured" guard still fires before any network call.
      final result = await repository.initiateCheckout(
        shippingAddressId: '550e8400-e29b-41d4-a716-446655440000',
        idempotencyKey: '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('not configured'));
    });

    test(
        'initiateCheckout without idempotencyKey still returns failure when unconfigured', () async {
      // The parameter is optional — omitting it is valid.
      final result = await repository.initiateCheckout(
        shippingAddressId: '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('not configured'));
    });
  });

  // =========================================================================
  // Section 3 — Skipped live-integration tests (documented gaps)
  // =========================================================================
  //
  // The following tests require a live PostgreSQL instance with migration 9
  // applied.  They are skipped in unit CI.  Run them manually against a local
  // Supabase stack (`supabase start`) to verify database-layer idempotency.

  group('Idempotency — live PostgreSQL tests (skipped in unit CI)', () {
    test(
      'RPC: same idempotency key returns identical customer_order_id (no duplicate)',
      () async {
        // Requires: live Supabase, migration 9 applied, two authenticated users.
        // Procedure:
        //   1. Call create_checkout_order with key K.
        //   2. Record customer_order_id = X.
        //   3. Call create_checkout_order again with the same key K.
        //   4. Expect customer_order_id = X (unchanged), idempotent_replay = true.
        //   5. Verify only ONE row in customer_orders was created.
      },
      skip: 'Requires live Supabase instance with migration 9 applied',
    );

    test(
      'RPC: concurrent requests with same key create exactly one order',
      () async {
        // Requires: live Supabase, the ability to run two concurrent DB connections.
        // Verifies: ON CONFLICT DO NOTHING on the idempotency_log table prevents
        // two simultaneous first-time calls from creating two orders.
      },
      skip: 'Requires concurrent DB connections — not available in unit CI',
    );

    test(
      'RPC: expired key (> 24 h) is ignored and a new order is created',
      () async {
        // Requires: live Supabase, ability to insert a backdated row into
        // checkout_idempotency_log (using service_role or test helper).
      },
      skip: 'Requires live Supabase instance with migration 9 applied',
    );

    test(
      'RPC: authenticated user cannot call create_checkout_order directly',
      () async {
        // Requires: live Supabase, JWT for a customer-role user.
        // Verifies: REVOKE EXECUTE FROM PUBLIC means authenticated role gets
        // permission denied when calling the RPC without service_role.
      },
      skip: 'Requires live Supabase instance — verify with psql or Supabase Studio',
    );
  });
}
