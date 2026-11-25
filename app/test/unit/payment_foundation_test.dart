// Tests for Payment Foundation & Atomic Settlement (Milestone 4.2).
//
// These tests verify:
//   • PaymentAttemptModel & PaymentSettlementResult parse all schema fields with canonical currency ('SLE').
//   • Successful settlement contract and state transitions.
//   • Failed settlement contract (order remains pending_payment for retry, stock not restored).
//   • Failed settlement idempotency (repeated failure callback returns idempotent_replay with existing transaction).
//   • Idempotent replay for duplicate settlement (original transaction returned, no duplicate ledger).
//   • Duplicate payment attempts prevention with identical idempotency key.
//   • Currency consistency (enforcing attempt currency matches settlement currency).
//   • Late success notification on cancelled order (flags reconciliation, notifies customer & admins).
//   • Safe order expiration logic (blocked while payment attempt is processing, stock restored exactly once).
//   • Inventory restoration exactly once under concurrent calls.
//   • RPC permission restrictions (revoked from public/anon/authenticated; service_role only).
//
// =============================================================================
// CI & INTEGRATION TEST STATUS DISCLOSURE:
// =============================================================================
// Section 1 contains pure Dart UNIT / CONTRACT tests that execute in local CI
// (flutter test test/ --coverage) without requiring a live database container.
//
// Section 2 contains PostgreSQL INTEGRATION TEST SPECIFICATIONS.
// IMPORTANT NOTE:
//   The six integration specifications in Section 2 are currently SKIPPED in CI
//   (`skip: true`) because neither flutter_ci.yml nor supabase_validate.yml
//   executes a test runner against a live PostgreSQL container.
//   They serve as the canonical contract specifications for a future live test harness.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/payment/data/models/payment_attempt_model.dart';
import 'package:salonemarket/features/payment/data/models/payment_settlement_result.dart';

void main() {
  group('Milestone 4.2: Payment Models & Contract Tests [Mocked / Unit]', () {
    const customerOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const customerId = '6ba7b810-9dad-41d1-80b4-00c04fd430c8';
    const paymentAttemptId = '7ca7b810-9dad-41d1-80b4-00c04fd430c9';
    const transactionId = '8da7b810-9dad-41d1-80b4-00c04fd430d0';
    const idempotencyKey = 'idem-key-test-uuid-12345';

    // 1. Successful settlement
    test('Successful settlement parses result, confirms order and records transaction', () {
      final jsonResponse = {
        'success': true,
        'idempotent_replay': false,
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
        'order_status': 'confirmed',
        'payment_status': 'paid',
        'transaction_id': transactionId,
        'transaction_reference': 'TX-ABC12345-20261121',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isTrue);
      expect(result.isIdempotentReplay, isFalse);
      expect(result.customerOrderId, equals(customerOrderId));
      expect(result.paymentAttemptId, equals(paymentAttemptId));
      expect(result.orderStatus, equals('confirmed'));
      expect(result.paymentStatus, equals('paid'));
      expect(result.transactionId, equals(transactionId));
      expect(result.transactionReference, equals('TX-ABC12345-20261121'));
      expect(result.requiresReconciliation, isFalse);
    });

    // 2. Failed settlement
    test('Failed settlement marks payment failed while leaving order pending_payment for retry', () {
      final jsonResponse = {
        'success': false,
        'order_status': 'pending_payment',
        'payment_status': 'failed',
        'attempt_status': 'failed',
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
        'transaction_id': transactionId,
        'transaction_reference': 'TX-FAIL1234-20261121',
        'failure_reason': 'Insufficient mobile money wallet balance',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.orderStatus, equals('pending_payment'));
      expect(result.paymentStatus, equals('failed'));
      expect(result.attemptStatus, equals('failed'));
      expect(result.failureReason, equals('Insufficient mobile money wallet balance'));
      expect(result.stockRestored, isFalse); // Stock must NOT be restored on mere attempt failure
    });

    // 3. Failed settlement idempotency (Repeated failure callback)
    test('Repeated failed settlement for same attempt returns idempotent_replay with existing transaction', () {
      final jsonResponse = {
        'success': false,
        'idempotent_replay': true,
        'order_status': 'pending_payment',
        'payment_status': 'failed',
        'attempt_status': 'failed',
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
        'transaction_id': transactionId,
        'transaction_reference': 'TX-FAIL1234-20261121',
        'failure_reason': 'Insufficient mobile money wallet balance',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.isIdempotentReplay, isTrue);
      expect(result.transactionId, equals(transactionId));
      expect(result.orderStatus, equals('pending_payment'));
      expect(result.paymentStatus, equals('failed'));
    });

    // 4. Duplicate settlement (Idempotent replay on success)
    test('Duplicate settlement with same attempt returns original result with idempotent_replay true', () {
      final jsonResponse = {
        'success': true,
        'idempotent_replay': true,
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
        'order_status': 'confirmed',
        'payment_status': 'paid',
        'transaction_id': transactionId,
        'transaction_reference': 'TX-ORIGINAL-20261121',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isTrue);
      expect(result.isIdempotentReplay, isTrue);
      expect(result.transactionId, equals(transactionId));
      expect(result.orderStatus, equals('confirmed'));
      expect(result.paymentStatus, equals('paid'));
    });

    // 5. Payment attempt model parses canonical currency ('SLE') and idempotency_key
    test('Payment attempt model defaults to SLE and recognizes idempotency_key', () {
      final jsonResponse = {
        'success': true,
        'idempotent_replay': true,
        'payment_attempt_id': paymentAttemptId,
        'reference': 'PA-MOCKREF-20261121',
        'status': 'processing',
        'amount': 250.0,
        'currency': 'SLE',
        'provider': 'simulated',
        'idempotency_key': idempotencyKey,
      };

      final attempt = PaymentAttemptModel.fromRpcResponse(jsonResponse);

      expect(attempt.id, equals(paymentAttemptId));
      expect(attempt.isIdempotentReplay, isTrue);
      expect(attempt.isProcessing, isTrue);
      expect(attempt.amount, equals(250.0));
      expect(attempt.currency, equals('SLE'));
      expect(attempt.idempotencyKey, equals(idempotencyKey));
    });

    // 6. Late success notification on cancelled order (Reconciliation handling)
    test('Late success notification on cancelled order triggers reconciliation requirement', () {
      final jsonResponse = {
        'success': false,
        'reconciliation_needed': true,
        'error': 'Payment received after order was cancelled. Flagged for admin reconciliation or refund.',
        'customer_order_id': customerOrderId,
        'order_status': 'cancelled',
        'payment_status': 'failed',
        'transaction_id': transactionId,
        'transaction_reference': 'TX-LATE-20261121',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.requiresReconciliation, isTrue);
      expect(result.orderStatus, equals('cancelled'));
      expect(result.transactionId, equals(transactionId));
      expect(result.error, contains('Flagged for admin reconciliation'));
    });

    // 7. Order expiration blocked when attempt is in processing status
    test('Order expiration is blocked when active processing attempt exists', () {
      final jsonResponse = {
        'success': false,
        'deferred': true,
        'error': 'Order has an unresolved payment attempt in processing state. Expiry blocked until payment outcome is finalized or explicitly forced with reconciliation.',
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.stockRestored, isFalse);
      expect(result.error, contains('unresolved payment attempt in processing state'));
    });

    // 8. Order expiration succeeds when no unresolved attempt exists
    test('Order expiration marks order cancelled and confirms stock_restored when safe', () {
      final jsonResponse = {
        'success': true,
        'customer_order_id': customerOrderId,
        'status': 'cancelled',
        'stock_restored': true,
        'reason': 'Payment reservation window expired (15 minutes)',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isTrue);
      expect(result.orderStatus, equals('cancelled'));
      expect(result.stockRestored, isTrue);
    });

    // 9. Lifecycle helper methods
    test('PaymentAttemptModel lifecycle state getters reflect status correctly', () {
      const base = PaymentAttemptModel(
        id: '1',
        customerOrderId: customerOrderId,
        customerId: customerId,
        method: 'mobile_money',
        provider: 'orange_money',
        amount: 150.0,
        currency: 'SLE',
        status: 'pending',
        reference: 'PA-TEST',
      );

      expect(base.isProcessing, isFalse);
      expect(base.isSucceeded, isFalse);

      final processing = PaymentAttemptModel.fromRpcResponse({...base.toJson(), 'status': 'processing'});
      expect(processing.isProcessing, isTrue);

      final succeeded = PaymentAttemptModel.fromRpcResponse({...base.toJson(), 'status': 'succeeded'});
      expect(succeeded.isSucceeded, isTrue);

      final cancelled = PaymentAttemptModel.fromRpcResponse({...base.toJson(), 'status': 'cancelled'});
      expect(cancelled.isCancelled, isTrue);

      final expired = PaymentAttemptModel.fromRpcResponse({...base.toJson(), 'status': 'expired'});
      expect(expired.isExpired, isTrue);

      final failed = PaymentAttemptModel.fromRpcResponse({...base.toJson(), 'status': 'failed'});
      expect(failed.isFailed, isTrue);
    });
  });

  // =========================================================================
  // Section 2 — Database Integration Test Specifications [Live PostgreSQL]
  // =========================================================================
  // NOTE: These tests are specifications that document the expected database
  // behavior. They declare `skip: true` and DO NOT execute in GitHub Actions CI
  // until a dedicated Supabase / PostgreSQL test runner job is configured.
  // =========================================================================
  group('Milestone 4.2: PostgreSQL Database Integration Tests [Integration Specification - Skipped in CI]', () {
    test(
      'Integration: create_or_get_payment_attempt rejects duplicate key for different order',
      () {
        // Enforced by unique index idx_payment_attempts_customer_idempotency
        // and RPC guard: IF v_existing_attempt.customer_order_id != p_customer_order_id THEN RAISE EXCEPTION
      },
      skip: true,
    );

    test(
      'Integration: settle_order_payment rejects currency mismatch between attempt and settlement',
      () {
        // Enforced by RPC guard:
        // IF v_attempt.currency != p_currency THEN RAISE EXCEPTION 'Currency mismatch ...'
      },
      skip: true,
    );

    test(
      'Integration: settle_order_payment prevents unauthenticated or non-owner caller',
      () {
        // Enforced by RPC ownership checks:
        // IF v_order.customer_id != p_customer_id THEN RAISE EXCEPTION ... ERRCODE = 'insufficient_privilege'
      },
      skip: true,
    );

    test(
      'Integration: settle_order_payment prevents concurrent double-settlement',
      () {
        // Enforced by customer_orders FOR UPDATE row-level lock and guard:
        // IF EXISTS (SELECT 1 FROM payment_attempts WHERE customer_order_id = ... AND status = 'succeeded')
      },
      skip: true,
    );

    test(
      'Integration: expire_unpaid_order restores stock exactly once',
      () {
        // Enforced by row lock FOR UPDATE and state transition to status = 'cancelled':
        // Subsequent calls evaluate IF v_order.status = 'cancelled' and return without looping
      },
      skip: true,
    );

    test(
      'Integration: RPC permissions strictly grant service_role and revoke public/anon/authenticated',
      () {
        // Enforced by REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC, anon, authenticated;
        // and GRANT EXECUTE ON FUNCTION ... TO service_role;
      },
      skip: true,
    );
  });
}
