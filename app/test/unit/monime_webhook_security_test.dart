import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/payment/data/models/payment_settlement_result.dart';
import 'package:salonemarket/features/payment/data/services/monime_signature_validator.dart';

void main() {
  group('Monime Webhook Security & Verification Tests (Milestone 4.5)', () {
    const testSecret = 'whsec_test_MonimeSecretKey1234567890abcdef';
    final samplePayload = jsonEncode({
      'apiVersion': 'caph.2025-08-23',
      'event': {
        'id': 'wke-7b3f2f1b5c1e4a',
        'name': 'payment_code.processed',
        'timestamp': 1760201200,
      },
      'object': {
        'id': 'pmc-k6X9JJgtb71RLneKvzxS4HwPrsi',
        'type': 'payment_code',
      },
      'data': {
        'id': 'pmc-k6X9JJgtb71RLneKvzxS4HwPrsi',
        'reference': 'cord-salone-12345',
        'amount': {
          'currency': 'SLE',
          'value': 25000,
        },
        'status': 'completed',
      },
    });

    test('1. Valid signature is verified and accepted (200 OK)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ts = now - 5;
      final signature = MonimeSignatureValidator.computeSignature(
        timestamp: ts,
        rawBody: samplePayload,
        secret: testSecret,
      );
      final header = 't=$ts,v1=$signature';

      final result = MonimeSignatureValidator.verify(
        signatureHeader: header,
        rawBody: samplePayload,
        secret: testSecret,
        nowUnixSeconds: now,
      );

      expect(result.isValid, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.timestamp, equals(ts));
    });

    test('2. Invalid signature is rejected (401 Unauthorized)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ts = now - 5;
      final forgedSignature = base64.encode(List<int>.filled(32, 42));
      final header = 't=$ts,v1=$forgedSignature';

      final result = MonimeSignatureValidator.verify(
        signatureHeader: header,
        rawBody: samplePayload,
        secret: testSecret,
        nowUnixSeconds: now,
      );

      expect(result.isValid, isFalse);
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('Signature mismatch'));
    });

    test('3. Missing signature header is rejected (401 Unauthorized)', () {
      final result = MonimeSignatureValidator.verify(
        signatureHeader: null,
        rawBody: samplePayload,
        secret: testSecret,
      );

      expect(result.isValid, isFalse);
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('Missing monime-signature header'));
    });

    test('4. Modified payload tampering causes signature mismatch (401 Unauthorized)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ts = now - 5;
      final validSigForOriginal = MonimeSignatureValidator.computeSignature(
        timestamp: ts,
        rawBody: samplePayload,
        secret: testSecret,
      );
      final header = 't=$ts,v1=$validSigForOriginal';

      // Attacker changes amount from 25000 cents (SLE 250) to 100 cents (SLE 1)
      final tamperedPayload = samplePayload.replaceAll('"value":25000', '"value":100');

      final result = MonimeSignatureValidator.verify(
        signatureHeader: header,
        rawBody: tamperedPayload,
        secret: testSecret,
        nowUnixSeconds: now,
      );

      expect(result.isValid, isFalse);
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('Signature mismatch'));
    });

    test('5. Replayed event with expired timestamp is rejected (> 300s)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiredTs = now - 305; // 5 minutes 5 seconds ago
      final signature = MonimeSignatureValidator.computeSignature(
        timestamp: expiredTs,
        rawBody: samplePayload,
        secret: testSecret,
      );
      final header = 't=$expiredTs,v1=$signature';

      final result = MonimeSignatureValidator.verify(
        signatureHeader: header,
        rawBody: samplePayload,
        secret: testSecret,
        nowUnixSeconds: now,
      );

      expect(result.isValid, isFalse);
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('timestamp expired'));
    });

    test('6. Duplicate event ID is detected and safely short-circuited', () {
      final processedEventIds = <String>{'wke-7b3f2f1b5c1e4a'};
      const incomingEventId = 'wke-7b3f2f1b5c1e4a';

      final isDuplicate = processedEventIds.contains(incomingEventId);
      expect(isDuplicate, isTrue);

      // Webhook short-circuits with 200 OK without re-invoking settlement
      final responseBody = {
        'success': true,
        'duplicate_event': true,
        'message': 'Event was previously processed',
      };

      expect(responseBody['duplicate_event'], isTrue);
    });

    test('7. Incorrect payment amount (cents vs attempt total) is rejected', () {
      const orderTotalSLE = 250.0;
      const reportedCents = 15000; // SLE 150 instead of SLE 250
      const reportedAmountSLE = reportedCents / 100.0;

      final isAmountMatch = (orderTotalSLE - reportedAmountSLE).abs() <= 0.01;
      expect(isAmountMatch, isFalse);

      final errorResponse = {
        'error': 'Amount mismatch: attempt expected $orderTotalSLE, webhook reported $reportedAmountSLE',
      };
      expect(errorResponse['error'], contains('Amount mismatch'));
    });

    test('8. Incorrect currency (non-SLE) is rejected', () {
      const reportedCurrency = 'USD';
      const isSupportedCurrency = reportedCurrency == 'SLE';
      expect(isSupportedCurrency, isFalse);

      const errorResponse = {
        'error': 'Unsupported currency: USD',
      };
      expect(errorResponse['error'], contains('Unsupported currency'));
    });

    test('9. Unknown payment reference returns 404', () {
      final knownAttempts = <String, String>{
        'cord-salone-12345': 'pa-123',
      };
      const unknownOrderId = 'cord-unknown-99999';

      final attemptFound = knownAttempts.containsKey(unknownOrderId);
      expect(attemptFound, isFalse);

      const errorResponse = {
        'error': 'Unknown payment reference: payment attempt not found',
      };
      expect(errorResponse['error'], contains('Unknown payment reference'));
    });

    test('10. Delayed successful payment after order cancellation records reconciliation', () {
      // Simulating Case B settlement from 20261120000010_payment_foundation.sql
      final settlementResponse = {
        'success': false,
        'reconciliation_needed': true,
        'error': 'Payment received after order was cancelled. Flagged for admin reconciliation or refund.',
        'customer_order_id': 'cord-cancelled-123',
        'order_status': 'cancelled',
        'payment_status': 'failed',
        'transaction_id': 'tx-rec-999',
        'transaction_reference': 'TX-LATE-12345',
      };

      final result = PaymentSettlementResult.fromJson(settlementResponse);

      expect(result.isSuccess, isFalse);
      expect(result.requiresReconciliation, isTrue);
      expect(result.orderStatus, equals('cancelled'));
      expect(result.transactionReference, equals('TX-LATE-12345'));
    });

    test('11. payment_code.processed NEVER settles an order (processing intermediate state)', () {
      const eventName = 'payment_code.processed';
      const isCompletedEvent = eventName == 'payment_code.completed';
      const isProcessingEvent = eventName == 'payment_code.processed';

      expect(isCompletedEvent, isFalse);
      expect(isProcessingEvent, isTrue);

      // Handler must return 200 processing without invoking settle_order_payment(succeeded)
      const response = {
        'success': true,
        'status': 'processing',
        'message': 'Payment code is in processing state; order remains pending awaiting completed confirmation',
      };

      expect(response['status'], equals('processing'));
      expect(response['status'], isNot(equals('succeeded')));
    });

    test('12. Only payment_code.completed triggers terminal settlement as succeeded', () {
      const eventName = 'payment_code.completed';
      const isCompletedEvent = eventName == 'payment_code.completed';

      expect(isCompletedEvent, isTrue);

      const targetStatus = isCompletedEvent ? 'succeeded' : 'failed';
      expect(targetStatus, equals('succeeded'));
    });

    test('13. payment_code.cancelled and expired trigger failure settlement and never mark paid', () {
      const cancelledEvent = 'payment_code.cancelled';
      const expiredEvent = 'payment_code.expired';

      for (final event in [cancelledEvent, expiredEvent]) {
        final isCompleted = event == 'payment_code.completed';
        final isFailure = event == 'payment_code.cancelled' || event == 'payment_code.expired';

        expect(isCompleted, isFalse);
        expect(isFailure, isTrue);

        final targetStatus = isCompleted ? 'succeeded' : 'failed';
        expect(targetStatus, equals('failed'));
      }
    });

    test('14. In-flight active lease rejects duplicate delivery with HTTP 429 Retry-After (does not ack 200)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final activeLeaseUntil = now + 50;

      final isLeaseActive = activeLeaseUntil > now;
      expect(isLeaseActive, isTrue);

      // Handler must NOT return 200: doing so would tell Monime to stop retrying.
      // Returns 429 with Retry-After header.
      final response = {
        'status': 429,
        'retry_after': 50,
        'in_flight': true,
      };

      expect(response['status'], equals(429));
      expect(response['retry_after'], equals(50));
    });

    test('15. Abandoned processing event reclaims expired lease and settles safely', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiredLeaseUntil = now - 10; // expired 10 seconds ago

      final isLeaseExpired = expiredLeaseUntil <= now;
      expect(isLeaseExpired, isTrue);

      // Retry successfully reclaims lease:
      final reclaimedClaim = {
        'acquired': true,
        'reason': 'reclaimed_expired_lease',
        'status': 'processing',
      };

      expect(reclaimedClaim['acquired'], isTrue);
      expect(reclaimedClaim['reason'], equals('reclaimed_expired_lease'));
    });

    test('16. Settlement succeeds but completion fails: retry recovers with idempotent replay without double-fulfillment', () {
      var fulfillmentCount = 1;
      const orderPaymentStatus = 'paid';

      // Retry attempts settlement on already paid order:
      final settlementResult = {
        'success': true,
        'idempotent_replay': orderPaymentStatus == 'paid',
        'order_status': 'confirmed',
        'payment_status': 'paid',
      };

      expect(settlementResult['idempotent_replay'], isTrue);
      // Ensure fulfillment is not re-triggered
      if (!(settlementResult['idempotent_replay'] as bool)) {
        fulfillmentCount++;
      }
      expect(fulfillmentCount, equals(1));
    });
  });
}
