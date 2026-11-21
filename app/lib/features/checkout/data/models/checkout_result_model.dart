/// Result payload returned from checkout initialization.
///
/// Matches the response contract of the `initiate-checkout` Supabase Edge Function.
class CheckoutResult {
  const CheckoutResult({
    required this.isSuccess,
    this.customerOrderId,
    this.vendorOrderIds = const [],
    this.total = 0.0,
    this.errorMessage,
    this.idempotencyKey,
    this.isIdempotentReplay = false,
  });

  factory CheckoutResult.fromMap(Map<String, dynamic> map) {
    final success = map['success'] == true;
    final totalNum = map['total'];
    final totalVal = totalNum is num
        ? totalNum.toDouble()
        : (double.tryParse(totalNum?.toString() ?? '') ?? 0.0);

    final rawVendorIds = map['vendor_order_ids'];
    final List<String> vendorIds = rawVendorIds is List
        ? rawVendorIds.map((e) => e.toString()).toList()
        : [];

    return CheckoutResult(
      isSuccess: success,
      customerOrderId: map['customer_order_id']?.toString(),
      vendorOrderIds: vendorIds,
      total: totalVal,
      errorMessage: map['error']?.toString(),
      idempotencyKey: map['idempotency_key']?.toString(),
      isIdempotentReplay: map['idempotent_replay'] == true,
    );
  }

  factory CheckoutResult.failure(String message) {
    return CheckoutResult(
      isSuccess: false,
      errorMessage: message,
    );
  }

  final bool isSuccess;
  final String? customerOrderId;
  final List<String> vendorOrderIds;
  final double total;
  final String? errorMessage;

  /// The idempotency key echoed back by the server.
  /// Store this and re-send on retry to avoid duplicate orders.
  final String? idempotencyKey;

  /// True when the server returned the result of a previously completed order
  /// without creating a new one (idempotent replay).
  final bool isIdempotentReplay;

  String get formattedTotal {
    if (total == total.roundToDouble()) {
      return 'SLE ${total.toInt()}';
    }
    return 'SLE ${total.toStringAsFixed(2)}';
  }
}
