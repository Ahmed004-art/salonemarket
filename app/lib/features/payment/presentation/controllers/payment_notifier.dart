import 'package:flutter/foundation.dart';
import '../../data/models/payment_settlement_result.dart';
import '../../data/repositories/payment_repository.dart';

enum PaymentStatus {
  initial,
  processing,
  succeeded,
  failed,
  pendingOrTimeout,
}

/// Central state manager for payment processing and provider transactions.
class PaymentNotifier extends ChangeNotifier {
  PaymentNotifier({PaymentRepository? repository})
      : _repository = repository ?? PaymentRepository();

  final PaymentRepository _repository;

  PaymentStatus _status = PaymentStatus.initial;
  String? _errorMessage;
  PaymentSettlementResult? _lastResult;

  PaymentStatus get status => _status;
  bool get isProcessing => _status == PaymentStatus.processing;
  bool get isSucceeded => _status == PaymentStatus.succeeded;
  bool get isFailed => _status == PaymentStatus.failed;
  bool get isPendingOrTimeout => _status == PaymentStatus.pendingOrTimeout;
  bool get canRetry => _status == PaymentStatus.failed;
  String? get errorMessage => _errorMessage;
  PaymentSettlementResult? get lastResult => _lastResult;

  /// Executes payment through the payment repository.
  Future<bool> processPayment({
    required String customerOrderId,
    String method = 'simulated',
    String provider = 'simulated',
    String? phoneNumber,
    String? idempotencyKey,
    double? expectedAmount,
  }) async {
    _status = PaymentStatus.processing;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.processPayment(
      customerOrderId: customerOrderId,
      method: method,
      provider: provider,
      phoneNumber: phoneNumber,
      idempotencyKey: idempotencyKey,
      expectedAmount: expectedAmount,
    );

    _lastResult = result;

    if (result.isSuccess) {
      _status = PaymentStatus.succeeded;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      if (result.paymentStatus == 'processing' ||
          (result.error != null && result.error!.contains('pending'))) {
        _status = PaymentStatus.pendingOrTimeout;
        _errorMessage = result.error ?? 'Payment outcome pending confirmation.';
      } else {
        _status = PaymentStatus.failed;
        _errorMessage = result.error ?? result.failureReason ?? 'Payment processing failed.';
      }
      notifyListeners();
      return false;
    }
  }

  /// Polls authoritative order status in Supabase to detect asynchronous
  /// Monime webhook settlement after USSD approval.
  Future<bool> refreshOrderStatus(String customerOrderId) async {
    final statusResult = await _repository.checkOrderPaymentStatus(
      customerOrderId: customerOrderId,
    );
    if (statusResult == null) return false;

    if (statusResult.isSuccess) {
      _lastResult = statusResult;
      _status = PaymentStatus.succeeded;
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    if (statusResult.paymentStatus == 'failed') {
      _lastResult = statusResult;
      _status = PaymentStatus.failed;
      _errorMessage =
          statusResult.failureReason ?? 'Payment was cancelled or expired.';
      notifyListeners();
    }
    return false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _status = PaymentStatus.initial;
    _errorMessage = null;
    _lastResult = null;
    notifyListeners();
  }
}
