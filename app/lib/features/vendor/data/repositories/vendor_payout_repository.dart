import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/vendor_payout_model.dart';

/// Repository coordinating vendor earnings ledger, payout destinations, and disbursement requests.
class VendorPayoutRepository {
  VendorPayoutRepository({SupabaseClient? client}) : _client = client;

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

  /// Fetches authoritative payout summary (total earned, paid out, pending, available balance).
  Future<VendorPayoutSummary?> getPayoutSummary(String vendorId) async {
    if (!isReady) return null;
    try {
      final res = await _effectiveClient.rpc(
        'vendor_get_payout_summary',
        params: {'p_vendor_id': vendorId},
      );
      if (res == null) return null;
      return VendorPayoutSummary.fromMap(res as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Fetches registered payout destinations for this vendor.
  Future<List<VendorPayoutDestination>> getDestinations(String vendorId) async {
    if (!isReady) return [];
    try {
      final res = await _effectiveClient
          .from('vendor_payout_destinations')
          .select()
          .eq('vendor_id', vendorId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> list = res as List<dynamic>;
      return list
          .map((item) =>
              VendorPayoutDestination.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a new payout destination (e.g. Orange Money or bank account).
  Future<bool> addDestination({
    required String vendorId,
    required String type,
    required String provider,
    required String accountNumber,
    required String accountName,
  }) async {
    if (!isReady) return false;
    try {
      await _effectiveClient.from('vendor_payout_destinations').insert({
        'vendor_id': vendorId,
        'type': type,
        'provider': provider,
        'account_number': accountNumber,
        'account_name': accountName,
        'is_default': true,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetches past payout requests and history.
  Future<List<VendorPayout>> getPayoutHistory(String vendorId) async {
    if (!isReady) return [];
    try {
      final res = await _effectiveClient
          .from('vendor_payouts')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      final List<dynamic> list = res as List<dynamic>;
      return list
          .map((item) => VendorPayout.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches immutable earnings ledger entries for auditability.
  Future<List<VendorLedgerEntry>> getLedgerEntries(String vendorId) async {
    if (!isReady) return [];
    try {
      final res = await _effectiveClient
          .from('vendor_earnings_ledger')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      final List<dynamic> list = res as List<dynamic>;
      return list
          .map((item) =>
              VendorLedgerEntry.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Submits a new payout request via server RPC.
  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String destinationId,
    String? notes,
  }) async {
    if (!isReady) {
      return {'success': false, 'message': 'Database not connected'};
    }

    try {
      final res = await _effectiveClient.rpc(
        'vendor_request_payout',
        params: {
          'p_amount': amount,
          'p_destination_id': destinationId,
          'p_notes': notes,
        },
      );
      return res as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
