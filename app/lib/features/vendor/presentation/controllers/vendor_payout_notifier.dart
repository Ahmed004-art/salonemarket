import 'package:flutter/foundation.dart';
import '../../data/models/vendor_payout_model.dart';
import '../../data/repositories/vendor_payout_repository.dart';

class VendorPayoutNotifier extends ChangeNotifier {
  VendorPayoutNotifier({VendorPayoutRepository? repository})
      : _repository = repository ?? VendorPayoutRepository();

  final VendorPayoutRepository _repository;

  VendorPayoutSummary? _summary;
  List<VendorPayoutDestination> _destinations = [];
  List<VendorPayout> _payouts = [];
  List<VendorLedgerEntry> _ledgerEntries = [];

  bool _isLoading = false;
  String? _errorMessage;

  VendorPayoutSummary? get summary => _summary;
  List<VendorPayoutDestination> get destinations => _destinations;
  List<VendorPayout> get payouts => _payouts;
  List<VendorLedgerEntry> get ledgerEntries => _ledgerEntries;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadPayoutData(String vendorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final summaryRes = await _repository.getPayoutSummary(vendorId);
      final destsRes = await _repository.getDestinations(vendorId);
      final payoutsRes = await _repository.getPayoutHistory(vendorId);
      final ledgerRes = await _repository.getLedgerEntries(vendorId);

      _summary = summaryRes;
      _destinations = destsRes;
      _payouts = payoutsRes;
      _ledgerEntries = ledgerRes;
    } catch (e) {
      _errorMessage = 'Failed to load payout details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDestination({
    required String vendorId,
    required String type,
    required String provider,
    required String accountNumber,
    required String accountName,
  }) async {
    final success = await _repository.addDestination(
      vendorId: vendorId,
      type: type,
      provider: provider,
      accountNumber: accountNumber,
      accountName: accountName,
    );

    if (success) {
      _destinations = await _repository.getDestinations(vendorId);
      notifyListeners();
    }
    return success;
  }

  Future<Map<String, dynamic>> submitPayoutRequest({
    required String vendorId,
    required double amount,
    required String destinationId,
    String? notes,
  }) async {
    final result = await _repository.requestPayout(
      amount: amount,
      destinationId: destinationId,
      notes: notes,
    );

    if (result['success'] == true) {
      // Reload summary and payouts
      await loadPayoutData(vendorId);
    }
    return result;
  }
}
