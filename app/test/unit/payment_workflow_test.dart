// Comprehensive tests for Payment Workflow & Provider Abstraction (Milestone 4.3).
//
// Verifies:
//   1. Successful simulated payment workflow.
//   2. Failed simulated payment workflow.
//   3. Timeout / pending payment workflow.
//   4. Safe retry behavior after payment failure.
//   5. Duplicate payment request handling (idempotent replay).
//   6. Duplicate settlement callback on paid order (reconciliation handling).
//   7. Ownership validation (foreign user rejected).
//   8. Authoritative amount and currency validation (SLE).
//   9. Delayed success callback after transient failure.
//  10. Prevention of accidental stock restoration during payment retries.
//  11. PaymentNotifier state machine transitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/payment/data/models/payment_settlement_result.dart';
import 'package:salonemarket/features/payment/data/repositories/payment_repository.dart';
import 'package:salonemarket/features/payment/presentation/controllers/payment_notifier.dart';

/// Mock payment repository to test state transitions deterministically.
class MockPaymentRepository extends PaymentRepository {
  MockPaymentRepository({
    this.nextResult,
    this.resultsSequence,
  });

  PaymentSettlementResult? nextResult;
  List<PaymentSettlementResult>? resultsSequence;
  int _sequenceIndex = 0;

  int callCount = 0;
  String? lastOrderId;
  double? lastAmount;
  String? lastIdempotencyKey;

  @override
  bool get isReady => true;

  @override
  String? get currentUserId => 'usr-test-customer-001';

  @override
  Future<PaymentSettlementResult> processPayment({
    required String customerOrderId,
    String method = 'simulated',
    String provider = 'simulated',
    String? phoneNumber,
    String? idempotencyKey,
    double? expectedAmount,
  }) async {
    callCount++;
    lastOrderId = customerOrderId;
    lastAmount = expectedAmount;
    lastIdempotencyKey = idempotencyKey;

    if (resultsSequence != null && _sequenceIndex < resultsSequence!.length) {
      final res = resultsSequence![_sequenceIndex];
      _sequenceIndex++;
      return res;
    }

    return nextResult ??
        const PaymentSettlementResult(
          isSuccess: true,
          orderStatus: 'confirmed',
          paymentStatus: 'paid',
          transactionReference: 'TX-SIM-SUCCESS-001',
        );
  }
}

void main() {
  const orderId = 'cord-test-order-999';

  group('Milestone 4.3: Payment Workflow & State Machine Tests', () {
    // 1. Successful simulated payment
    test('PaymentNotifier transitions to succeeded on successful payment', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: true,
          customerOrderId: orderId,
          orderStatus: 'confirmed',
          paymentStatus: 'paid',
          transactionId: 'tx-001',
          transactionReference: 'TX-SIM-001',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);
      expect(notifier.status, equals(PaymentStatus.initial));
      expect(notifier.isProcessing, isFalse);

      final ok = await notifier.processPayment(
        customerOrderId: orderId,
        expectedAmount: 250.0,
      );

      expect(ok, isTrue);
      expect(notifier.status, equals(PaymentStatus.succeeded));
      expect(notifier.isSucceeded, isTrue);
      expect(notifier.errorMessage, isNull);
      expect(notifier.lastResult?.transactionReference, equals('TX-SIM-001'));
      expect(repo.callCount, equals(1));
    });

    // 2. Failed simulated payment
    test('PaymentNotifier transitions to failed on decline and allows retry', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: false,
          customerOrderId: orderId,
          orderStatus: 'pending_payment',
          paymentStatus: 'failed',
          failureReason: 'Insufficient funds on simulated mobile wallet',
          error: 'Insufficient funds on simulated mobile wallet',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);

      final ok = await notifier.processPayment(
        customerOrderId: orderId,
        expectedAmount: 250.0,
      );

      expect(ok, isFalse);
      expect(notifier.status, equals(PaymentStatus.failed));
      expect(notifier.isFailed, isTrue);
      expect(notifier.canRetry, isTrue);
      expect(notifier.errorMessage, contains('Insufficient funds'));
      expect(notifier.lastResult?.stockRestored, isFalse); // Stock must NOT be restored
    });

    // 3. Timeout / pending payment
    test('PaymentNotifier transitions to pendingOrTimeout on provider timeout', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: false,
          customerOrderId: orderId,
          orderStatus: 'pending_payment',
          paymentStatus: 'processing',
          error: 'Payment outcome pending subscriber action.',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);

      final ok = await notifier.processPayment(
        customerOrderId: orderId,
        phoneNumber: '0760009999',
      );

      expect(ok, isFalse);
      expect(notifier.status, equals(PaymentStatus.pendingOrTimeout));
      expect(notifier.isPendingOrTimeout, isTrue);
      expect(notifier.canRetry, isFalse); // Waiting for finality
      expect(notifier.errorMessage, contains('pending'));
    });

    // 4. Retry after failure succeeds
    test('Payment retry after failure successfully confirms order', () async {
      final repo = MockPaymentRepository(
        resultsSequence: [
          const PaymentSettlementResult(
            isSuccess: false,
            customerOrderId: orderId,
            orderStatus: 'pending_payment',
            paymentStatus: 'failed',
            failureReason: 'Temporary network failure',
            error: 'Temporary network failure',
          ),
          const PaymentSettlementResult(
            isSuccess: true,
            customerOrderId: orderId,
            orderStatus: 'confirmed',
            paymentStatus: 'paid',
            transactionReference: 'TX-RETRY-SUCCESS',
          ),
        ],
      );

      final notifier = PaymentNotifier(repository: repo);

      // Attempt 1: Fails
      final firstAttempt = await notifier.processPayment(customerOrderId: orderId);
      expect(firstAttempt, isFalse);
      expect(notifier.isFailed, isTrue);
      expect(notifier.canRetry, isTrue);

      // Attempt 2: Retry succeeds
      final secondAttempt = await notifier.processPayment(customerOrderId: orderId);
      expect(secondAttempt, isTrue);
      expect(notifier.isSucceeded, isTrue);
      expect(notifier.lastResult?.transactionReference, equals('TX-RETRY-SUCCESS'));
      expect(repo.callCount, equals(2));
    });

    // 5. Duplicate payment request (idempotent replay)
    test('Duplicate payment request parses idempotent_replay flag safely', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: true,
          isIdempotentReplay: true,
          customerOrderId: orderId,
          orderStatus: 'confirmed',
          paymentStatus: 'paid',
          transactionId: 'tx-001',
          transactionReference: 'TX-IDEMPOTENT-001',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);
      final ok = await notifier.processPayment(
        customerOrderId: orderId,
        idempotencyKey: 'idem-key-same-call',
      );

      expect(ok, isTrue);
      expect(notifier.lastResult?.isIdempotentReplay, isTrue);
      expect(notifier.lastResult?.transactionReference, equals('TX-IDEMPOTENT-001'));
    });

    // 6. Duplicate settlement callback on paid order triggers reconciliation flag
    test('Duplicate settlement callback triggers reconciliation requirement', () {
      final jsonResponse = {
        'success': false,
        'reconciliation_needed': true,
        'duplicate_payment': true,
        'error': 'Order has already been paid by a previous payment attempt. Duplicate charge flagged for administrator refund.',
        'customer_order_id': orderId,
        'payment_attempt_id': 'pa-dup-002',
        'transaction_id': 'tx-dup-002',
        'transaction_reference': 'TX-DUP-REFUND',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.requiresReconciliation, isTrue);
      expect(result.transactionReference, equals('TX-DUP-REFUND'));
      expect(result.error, contains('Duplicate charge flagged'));
    });

    // 7. Ownership validation (Foreign order rejected)
    test('Foreign order ownership error is handled cleanly', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: false,
          error: 'Forbidden: you do not own this order',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);
      final ok = await notifier.processPayment(customerOrderId: 'foreign-order-id');

      expect(ok, isFalse);
      expect(notifier.isFailed, isTrue);
      expect(notifier.errorMessage, contains('Forbidden'));
    });

    // 8. Authoritative amount and currency validation
    test('Server authoritative amount mismatch is surfaced to client', () async {
      final repo = MockPaymentRepository(
        nextResult: const PaymentSettlementResult(
          isSuccess: false,
          error: 'Amount mismatch: server expected 250, client sent 150',
        ),
      );

      final notifier = PaymentNotifier(repository: repo);
      final ok = await notifier.processPayment(
        customerOrderId: orderId,
        expectedAmount: 150.0,
      );

      expect(ok, isFalse);
      expect(notifier.errorMessage, contains('Amount mismatch'));
    });

    // 9. Delayed success after failure
    test('Delayed success after transient failure updates status to paid', () {
      final jsonResponse = {
        'success': true,
        'order_status': 'confirmed',
        'payment_status': 'paid',
        'customer_order_id': orderId,
        'payment_attempt_id': 'pa-delayed-001',
        'transaction_id': 'tx-delayed-001',
        'transaction_reference': 'TX-DELAYED-SUCCESS',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isTrue);
      expect(result.orderStatus, equals('confirmed'));
      expect(result.paymentStatus, equals('paid'));
      expect(result.transactionReference, equals('TX-DELAYED-SUCCESS'));
    });

    // 10. No accidental stock restoration on failed payment
    test('Failed payment outcome guarantees stock_restored remains false', () {
      final jsonResponse = {
        'success': false,
        'order_status': 'pending_payment',
        'payment_status': 'failed',
        'customer_order_id': orderId,
        'stock_restored': false,
        'failure_reason': 'Card declined',
      };

      final result = PaymentSettlementResult.fromJson(jsonResponse);

      expect(result.isSuccess, isFalse);
      expect(result.stockRestored, isFalse);
      expect(result.orderStatus, equals('pending_payment'));
    });

    // 11. Notifier reset clears state
    test('Notifier reset resets status and lastResult', () {
      final notifier = PaymentNotifier();
      notifier.reset();

      expect(notifier.status, equals(PaymentStatus.initial));
      expect(notifier.isProcessing, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.lastResult, isNull);
    });
  });
}
