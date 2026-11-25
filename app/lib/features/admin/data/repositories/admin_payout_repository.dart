import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/admin_payout_model.dart';

/// Repository for privileged administrative payout management.
class AdminPayoutRepository {
  AdminPayoutRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient {
    if (_client != null) return _client;
    if (AppConstants.isSupabaseConfigured) {
      return Supabase.instance.client;
    }
    throw StateError('Supabase is not configured.');
  }

  bool get isReady => _client != null || AppConstants.isSupabaseConfigured;

  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches all vendor payout requests with optional status filtering.
  Future<List<AdminPayoutItem>> getPayoutRequests({String? status}) async {
    if (!isReady) return [];
    final res = await _effectiveClient.rpc(
      'admin_get_payout_requests',
      params: {'p_status': status ?? 'all'},
    ).timeout(_timeout);

    final List<dynamic> list = res as List<dynamic>;
    return list
        .map((item) => AdminPayoutItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Authorizes and disburses a payout with recorded provider transaction reference.
  Future<Map<String, dynamic>> approveAndDisburse({
    required String payoutId,
    required String disbursementMethod, // 'monime_payout' or 'manual'
    String? providerRef,
    String? notes,
  }) async {
    if (!isReady) {
      return {'success': false, 'message': 'Database not connected'};
    }

    try {
      final res = await _effectiveClient.rpc(
        'admin_approve_and_disburse_payout',
        params: {
          'p_payout_id': payoutId,
          'p_disbursement_method': disbursementMethod,
          'p_provider_ref': providerRef,
          'p_admin_notes': notes,
        },
      ).timeout(_timeout);
      return res as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Rejects a payout request and restores vendor available balance.
  Future<Map<String, dynamic>> rejectPayout({
    required String payoutId,
    required String reason,
  }) async {
    if (!isReady) {
      return {'success': false, 'message': 'Database not connected'};
    }

    try {
      final res = await _effectiveClient.rpc(
        'admin_reject_payout',
        params: {
          'p_payout_id': payoutId,
          'p_reason': reason,
        },
      ).timeout(_timeout);
      return res as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
