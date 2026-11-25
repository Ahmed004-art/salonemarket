/// Represents a customer payment attempt record in SaloneMarket.
/// Aligns with public.payment_attempts schema and RPC create_or_get_payment_attempt.
class PaymentAttemptModel {
  const PaymentAttemptModel({
    required this.id,
    required this.customerOrderId,
    required this.customerId,
    required this.method,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.status,
    required this.reference,
    this.providerReference,
    this.isSimulated = true,
    this.failureReason,
    this.idempotencyKey,
    this.isIdempotentReplay = false,
    this.initiatedAt,
    this.completedAt,
    this.metadata = const {},
  });

  factory PaymentAttemptModel.fromRpcResponse(Map<String, dynamic> json) {
    return PaymentAttemptModel(
      id: json['payment_attempt_id'] as String? ?? json['id'] as String? ?? '',
      customerOrderId: json['customer_order_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      method: json['method'] as String? ?? 'simulated',
      provider: json['provider'] as String? ?? 'simulated',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'SLE',
      status: json['status'] as String? ?? 'pending',
      reference: json['reference'] as String? ?? '',
      providerReference: json['provider_reference'] as String?,
      isSimulated: json['is_simulated'] as bool? ?? true,
      failureReason: json['failure_reason'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      isIdempotentReplay: json['idempotent_replay'] as bool? ?? false,
      initiatedAt: json['initiated_at'] != null
          ? DateTime.tryParse(json['initiated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String id;
  final String customerOrderId;
  final String customerId;
  final String method;
  final String provider;
  final double amount;
  final String currency;
  final String status;
  final String reference;
  final String? providerReference;
  final bool isSimulated;
  final String? failureReason;
  final String? idempotencyKey;
  final bool isIdempotentReplay;
  final DateTime? initiatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  bool get isProcessing => status == 'processing';
  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_order_id': customerOrderId,
        'customer_id': customerId,
        'method': method,
        'provider': provider,
        'amount': amount,
        'currency': currency,
        'status': status,
        'reference': reference,
        'provider_reference': providerReference,
        'is_simulated': isSimulated,
        'failure_reason': failureReason,
        'idempotency_key': idempotencyKey,
        'idempotent_replay': isIdempotentReplay,
        'initiated_at': initiatedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'metadata': metadata,
      };
}
