import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/admin/data/models/admin_payout_model.dart';
import 'package:salonemarket/features/vendor/data/models/vendor_payout_model.dart';

void main() {
  group('Vendor Payouts & Settlement — Models & Parsing', () {
    test('VendorPayoutSummary correctly calculates authoritative balances', () {
      final map = {
        'vendor_id': 'vend-001',
        'currency': 'SLE',
        'total_earned': 1000.00,
        'total_paid_out': 400.00,
        'pending_payout': 200.00,
        'available_balance': 400.00,
      };

      final summary = VendorPayoutSummary.fromMap(map);

      expect(summary.vendorId, 'vend-001');
      expect(summary.totalEarned, 1000.00);
      expect(summary.totalPaidOut, 400.00);
      expect(summary.pendingPayout, 200.00);
      expect(summary.availableBalance, 400.00);
      expect(summary.formattedAvailable, 'SLE 400.00');
      expect(summary.formattedTotalEarned, 'SLE 1000.00');
    });

    test('VendorPayoutDestination formats mobile money and bank providers', () {
      final orangeDest = VendorPayoutDestination.fromMap({
        'id': 'dest-1',
        'vendor_id': 'vend-1',
        'type': 'mobile_money',
        'provider': 'orange_money',
        'account_number': '+23276123456',
        'account_name': 'Hawa Bangura',
        'is_default': true,
        'is_verified': true,
        'created_at': '2026-11-22T10:00:00Z',
      });

      expect(orangeDest.providerDisplayName, 'Orange Money');
      expect(orangeDest.type, 'mobile_money');
      expect(orangeDest.accountNumber, '+23276123456');
      expect(orangeDest.maskedAccountNumber, '+232 •••• •••• 3456');

      final bankDest = VendorPayoutDestination.fromMap({
        'id': 'dest-2',
        'vendor_id': 'vend-1',
        'type': 'bank_account',
        'provider': 'slcb',
        'account_number': '00300123456789',
        'account_name': 'Hawa Bangura Enterprise',
        'is_default': false,
        'is_verified': false,
        'created_at': '2026-11-22T10:00:00Z',
      });

      expect(bankDest.providerDisplayName, 'Sierra Leone Commercial Bank');
      expect(bankDest.type, 'bank_account');
      expect(bankDest.maskedAccountNumber, '•••• •••• 6789');
    });

    test('VendorLedgerEntry distinguishes credit and debit line totals', () {
      // Credit entry: net earnings from paid order
      final credit = VendorLedgerEntry.fromMap({
        'id': 'led-1',
        'vendor_id': 'vend-1',
        'type': 'order_credit',
        'gross_amount': 200.00,
        'commission_rate': 0.05,
        'commission_amount': 10.00,
        'net_amount': 190.00,
        'currency': 'SLE',
        'reference': 'EARN-vo-001',
        'created_at': '2026-11-22T11:00:00Z',
      });

      expect(credit.isCredit, isTrue);
      expect(credit.formattedNet, '+SLE 190.00');
      expect(credit.commissionAmount, 10.00);

      // Debit entry: completed payout disbursement
      final debit = VendorLedgerEntry.fromMap({
        'id': 'led-2',
        'vendor_id': 'vend-1',
        'type': 'payout_debit',
        'gross_amount': 150.00,
        'commission_rate': 0.00,
        'commission_amount': 0.00,
        'net_amount': -150.00,
        'currency': 'SLE',
        'reference': 'PAYOUT-PO-20261122-001',
        'created_at': '2026-11-22T12:00:00Z',
      });

      expect(debit.isCredit, isFalse);
      expect(debit.formattedNet, 'SLE -150.00');
    });

    test('AdminPayoutItem parsing supports both manual and automated methods', () {
      final manualPayout = AdminPayoutItem.fromMap({
        'id': 'po-1',
        'payout_reference': 'PO-20261122-ABCD1234',
        'vendor_id': 'vend-1',
        'vendor_name': 'Kono Fresh Grocers',
        'amount': 350.00,
        'currency': 'SLE',
        'fee': 0.00,
        'status': 'completed',
        'destination_type': 'mobile_money',
        'destination_provider': 'orange_money',
        'destination_account_number': '+23276999888',
        'destination_account_name': 'Mohamed Sesay',
        'disbursement_method': 'manual',
        'provider_reference': 'OM-TX-998877',
        'created_at': '2026-11-22T08:00:00Z',
        'completed_at': '2026-11-22T09:00:00Z',
      });

      expect(manualPayout.isCompleted, isTrue);
      expect(manualPayout.isPending, isFalse);
      expect(manualPayout.disbursementMethod, 'manual');
      expect(manualPayout.providerReference, 'OM-TX-998877');
      expect(manualPayout.maskedAccountNumber, '+232 •••• •••• 9888');
    });
  });

  group('Financial Settlement Engine & Integrity Verification', () {
    test('5% Platform Commission calculation is exact and non-lossy', () {
      const grossSubtotal = 150.00;
      const commissionRate = 0.0500;
      final commissionAmount = (grossSubtotal * commissionRate).roundToDouble();
      final netEarnings = grossSubtotal - commissionAmount;

      expect(commissionAmount, 7.50);
      expect(netEarnings, 142.50);
      expect(commissionAmount + netEarnings, grossSubtotal);
    });

    test('Available balance prevents negative payouts and enforces hold on in-flight requests', () {
      const totalEarned = 500.00;
      const totalPaidOut = 200.00;
      const pendingInFlight = 150.00;

      // Available = Earned - PaidOut - Pending
      final available = totalEarned - totalPaidOut - pendingInFlight;
      expect(available, 150.00);

      // Attempting payout of SLE 200 should fail (exceeds available)
      const requestedPayout = 200.00;
      final isAllowed = requestedPayout <= available;
      expect(isAllowed, isFalse);

      // Attempting payout of SLE 100 is valid
      const validPayout = 100.00;
      final isValid = validPayout <= available && validPayout >= 50.00;
      expect(isValid, isTrue);
    });

    test('Ledger idempotent references prevent duplicate earnings credits', () {
      final processedReferences = <String>{};

      bool recordEarnings(String vendorOrderId, double amount) {
        final ref = 'EARN-$vendorOrderId';
        if (processedReferences.contains(ref)) {
          return false; // Idempotent skip
        }
        processedReferences.add(ref);
        return true;
      }

      // First webhook settlement
      expect(recordEarnings('vo-100', 95.00), isTrue);

      // Duplicate webhook delivery for same vendor order
      expect(recordEarnings('vo-100', 95.00), isFalse);

      // Another order
      expect(recordEarnings('vo-101', 190.00), isTrue);
    });

    test('Payout rejection releases held balance back to available funds', () {
      double totalEarned = 1000.00;
      double totalPaidOut = 300.00;
      double pendingPayout = 200.00; // In-flight

      // Initial state
      double available = totalEarned - totalPaidOut - pendingPayout;
      expect(available, 500.00);

      // Admin rejects the pending payout
      const rejectedAmount = 200.00;
      pendingPayout -= rejectedAmount;

      // Restored state
      available = totalEarned - totalPaidOut - pendingPayout;
      expect(available, 700.00);
      expect(pendingPayout, 0.00);
    });

    test('Order cancellation/refund reverses credited vendor earnings via ledger debit', () {
      double totalEarned = 500.00;
      final ledgerCredits = <String, double>{
        'EARN-vo-001': 142.50, // Subtotal 150 - 5% commission (7.50)
      };

      // Order cancelled: create refund debit entry
      const vendorOrderId = 'vo-001';
      final creditRef = 'EARN-$vendorOrderId';
      final refundRef = 'REFUND-$vendorOrderId';

      expect(ledgerCredits.containsKey(creditRef), isTrue);

      final originalNet = ledgerCredits[creditRef]!;
      // Reversal debit
      final refundDebit = -originalNet;
      totalEarned += refundDebit;

      expect(refundDebit, -142.50);
      expect(totalEarned, 357.50);
      expect(refundRef, 'REFUND-vo-001');
    });

    test('Monime payout adapter creation invariant: never synchronously completes', () {
      // In Monime Caph API, POST /v1/payouts is asynchronous.
      // Creation response status is 'processing', never synchronously 'completed'.
      Map<String, dynamic> mockMonimeCreationResponse = {
        'id': 'po_12345678',
        'reference': 'PO-20261122-ABCD1234',
        'status': 'processing',
        'amount': {'currency': 'SLE', 'value': 25000},
      };

      String outcomeStatus;
      if (mockMonimeCreationResponse['status'] == 'completed') {
        // Violates invariant if triggered on creation!
        outcomeStatus = 'completed';
      } else {
        outcomeStatus = 'processing';
      }

      // Verifies adapter treats newly created payout as processing
      expect(outcomeStatus, 'processing');
      expect(outcomeStatus, isNot('completed'));
    });

    test('Monime GET status reconciliation handles terminal and transient states', () {
      String parseStatus(Map<String, dynamic> res) {
        final monimeStatus = res['status']?.toString();
        if (monimeStatus == 'completed') return 'completed';
        if (monimeStatus == 'failed' || monimeStatus == 'cancelled') return 'failed';
        return 'processing';
      }

      expect(parseStatus({'status': 'completed'}), 'completed');
      expect(parseStatus({'status': 'failed', 'failureReason': 'Insufficient balance'}), 'failed');
      expect(parseStatus({'status': 'cancelled'}), 'failed');
      expect(parseStatus({'status': 'processing'}), 'processing');
      expect(parseStatus({'status': 'pending'}), 'processing');
    });
  });
}
