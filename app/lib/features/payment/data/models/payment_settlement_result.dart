/// Represents the result of an atomic payment settlement RPC call.
/// Aligns with public.settle_order_payment and public.expire_unpaid_order.
class PaymentSettlementResult {
  const PaymentSettlementResult({
    required this.isSuccess,
    this.isIdempotentReplay = false,
    this.customerOrderId,
    this.paymentAttemptId,
    this.orderStatus,
    this.paymentStatus,
    this.attemptStatus,
    this.transactionId,
    this.transactionReference,
    this.error,
    this.requiresReconciliation = false,
    this.failureReason,
    this.stockRestored = false,
    this.ussdCode,
    this.requiresAction = false,
    this.actionMessage,
    this.isSimulated = false,
  });

  factory PaymentSettlementResult.fromJson(Map<String, dynamic> json) {
    return PaymentSettlementResult(
      isSuccess: json['success'] as bool? ?? false,
      isIdempotentReplay: json['idempotent_replay'] as bool? ?? false,
      customerOrderId: json['customer_order_id'] as String?,
      paymentAttemptId: json['payment_attempt_id'] as String?,
      orderStatus: json['order_status'] as String? ?? json['status'] as String?,
      paymentStatus: json['payment_status'] as String?,
      attemptStatus: json['attempt_status'] as String?,
      transactionId: json['transaction_id'] as String?,
      transactionReference: json['transaction_reference'] as String?,
      error: json['error'] as String?,
      requiresReconciliation: json['reconciliation_needed'] as bool? ?? false,
      failureReason: json['failure_reason'] as String?,
      stockRestored: json['stock_restored'] as bool? ?? false,
      ussdCode: json['ussd_code'] as String?,
      requiresAction: json['requires_action'] as bool? ?? false,
      actionMessage: json['action_message'] as String? ?? json['message'] as String?,
      isSimulated: json['is_simulated'] as bool? ?? false,
    );
  }

  final bool isSuccess;
  final bool isIdempotentReplay;
  final String? customerOrderId;
  final String? paymentAttemptId;
  final String? orderStatus;
  final String? paymentStatus;
  final String? attemptStatus;
  final String? transactionId;
  final String? transactionReference;
  final String? error;
  final bool requiresReconciliation;
  final String? failureReason;
  final bool stockRestored;
  final String? ussdCode;
  final bool requiresAction;
  final String? actionMessage;
  final bool isSimulated;

  Map<String, dynamic> toJson() => {
        'success': isSuccess,
        'idempotent_replay': isIdempotentReplay,
        'customer_order_id': customerOrderId,
        'payment_attempt_id': paymentAttemptId,
        'order_status': orderStatus,
        'payment_status': paymentStatus,
        'attempt_status': attemptStatus,
        'transaction_id': transactionId,
        'transaction_reference': transactionReference,
        'error': error,
        'reconciliation_needed': requiresReconciliation,
        'failure_reason': failureReason,
        'stock_restored': stockRestored,
        'ussd_code': ussdCode,
        'requires_action': requiresAction,
        'action_message': actionMessage,
        'is_simulated': isSimulated,
      };
}
