import 'package:flutter/foundation.dart';
import '../../data/models/admin_payout_model.dart';
import '../../data/repositories/admin_payout_repository.dart';

class AdminPayoutNotifier extends ChangeNotifier {
  AdminPayoutNotifier({AdminPayoutRepository? repository})
      : _repository = repository ?? AdminPayoutRepository();

  final AdminPayoutRepository _repository;

  List<AdminPayoutItem> _payouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedStatus = 'all';

  List<AdminPayoutItem> get payouts => _payouts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedStatus => _selectedStatus;

  int get pendingCount => _payouts.where((p) => p.isPending).length;

  Future<void> loadPayouts({String? status}) async {
    if (status != null) {
      _selectedStatus = status;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _payouts = await _repository.getPayoutRequests(status: _selectedStatus);
    } catch (e) {
      _errorMessage = 'Failed to load payout requests.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> approveAndDisburse({
    required String payoutId,
    required String disbursementMethod,
    String? providerRef,
    String? notes,
  }) async {
    final res = await _repository.approveAndDisburse(
      payoutId: payoutId,
      disbursementMethod: disbursementMethod,
      providerRef: providerRef,
      notes: notes,
    );

    if (res['success'] == true) {
      await loadPayouts();
    }
    return res;
  }

  Future<Map<String, dynamic>> rejectPayout({
    required String payoutId,
    required String reason,
  }) async {
    final res = await _repository.rejectPayout(
      payoutId: payoutId,
      reason: reason,
    );

    if (res['success'] == true) {
      await loadPayouts();
    }
    return res;
  }
}
