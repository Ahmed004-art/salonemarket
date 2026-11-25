import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/payment_settlement_result.dart';

/// Repository coordinating payment execution via the `process-payment` Supabase Edge Function.
class PaymentRepository {
  PaymentRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient {
    if (_client != null) return _client;
    if (AppConstants.isSupabaseConfigured) {
      return Supabase.instance.client;
    }
    throw StateError('Supabase is not configured.');
  }

  bool get isReady => _client != null || AppConstants.isSupabaseConfigured;

  String? get currentUserId =>
      _client?.auth.currentUser?.id ?? SupabaseService.instance.currentUserId;

  /// Calls the `process-payment` Edge Function with customer order details,
  /// selected payment provider, and optional client idempotency key.
  Future<PaymentSettlementResult> processPayment({
    required String customerOrderId,
    String method = 'simulated',
    String provider = 'simulated',
    String? phoneNumber,
    String? idempotencyKey,
    double? expectedAmount,
  }) async {
    if (!isReady) {
      return const PaymentSettlementResult(
        isSuccess: false,
        error: 'Backend database is not configured.',
      );
    }

    final userId = currentUserId;
    if (userId == null) {
      return const PaymentSettlementResult(
        isSuccess: false,
        error: 'Customer is not authenticated.',
      );
    }

    try {
      final payload = <String, dynamic>{
        'customer_order_id': customerOrderId,
        'method': method,
        'provider': provider,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotency_key': idempotencyKey,
        if (expectedAmount != null)
          'expected_amount': expectedAmount,
      };

      final response = await _effectiveClient.functions.invoke(
        'process-payment',
        body: payload,
      );

      final rawData = response.data;
      Map<String, dynamic> data;

      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        data = jsonDecode(rawData) as Map<String, dynamic>;
      } else {
        return const PaymentSettlementResult(
          isSuccess: false,
          error: 'Unexpected response format from payment gateway.',
        );
      }

      if (response.status >= 400) {
        return PaymentSettlementResult(
          isSuccess: false,
          error: data['error'] as String? ?? 'Payment processing failed (${response.status}).',
        );
      }

      return PaymentSettlementResult.fromJson(data);
    } on FunctionException catch (e) {
      String errorMessage = 'Payment processing failed.';
      if (e.details is Map) {
        errorMessage = (e.details as Map)['error']?.toString() ?? errorMessage;
      }
      return PaymentSettlementResult(
        isSuccess: false,
        error: errorMessage,
      );
    } catch (e) {
      return PaymentSettlementResult(
        isSuccess: false,
        error: 'Network error or gateway timeout: $e',
      );
    }
  }

  /// Checks the authoritative payment & order status from Supabase.
  /// Used to detect live webhook settlement while awaiting Monime USSD approval.
  Future<PaymentSettlementResult?> checkOrderPaymentStatus({
    required String customerOrderId,
  }) async {
    if (!isReady) return null;
    try {
      final order = await _effectiveClient
          .from('customer_orders')
          .select('id, status, payment_status')
          .eq('id', customerOrderId)
          .maybeSingle();
      if (order == null) return null;

      final paymentStatus = order['payment_status'] as String?;
      final orderStatus = order['status'] as String?;

      if (paymentStatus == 'paid' && orderStatus == 'confirmed') {
        final tx = await _effectiveClient
            .from('transactions')
            .select('id, reference, is_simulated')
            .eq('customer_order_id', customerOrderId)
            .eq('status', 'succeeded')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        return PaymentSettlementResult(
          isSuccess: true,
          customerOrderId: customerOrderId,
          orderStatus: orderStatus,
          paymentStatus: paymentStatus,
          transactionId: tx?['id'] as String?,
          transactionReference: tx?['reference'] as String?,
          isSimulated: tx?['is_simulated'] as bool? ?? false,
        );
      }

      if (paymentStatus == 'failed') {
        return PaymentSettlementResult(
          isSuccess: false,
          customerOrderId: customerOrderId,
          orderStatus: orderStatus,
          paymentStatus: paymentStatus,
          failureReason: 'Payment was cancelled, expired, or declined.',
          error: 'Payment was cancelled, expired, or declined.',
        );
      }

      return PaymentSettlementResult(
        isSuccess: false,
        customerOrderId: customerOrderId,
        orderStatus: orderStatus,
        paymentStatus: paymentStatus ?? 'processing',
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches structured receipt for a settled order via the `generate-receipt` Edge Function.
  Future<Map<String, dynamic>?> getReceipt({required String customerOrderId}) async {
    if (!isReady) return null;
    try {
      final response = await _effectiveClient.functions.invoke(
        'generate-receipt',
        body: {'customer_order_id': customerOrderId},
      );
      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        return rawData;
      } else if (rawData is String) {
        return jsonDecode(rawData) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
