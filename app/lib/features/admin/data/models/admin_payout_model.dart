/// Admin view of a vendor payout request.
class AdminPayoutItem {
  const AdminPayoutItem({
    required this.id,
    required this.payoutReference,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    required this.currency,
    required this.fee,
    required this.status,
    required this.destinationType,
    required this.destinationProvider,
    required this.destinationAccountNumber,
    required this.destinationAccountName,
    required this.disbursementMethod,
    this.providerReference,
    this.failureReason,
    this.adminNotes,
    required this.createdAt,
    this.completedAt,
  });

  factory AdminPayoutItem.fromMap(Map<String, dynamic> map) {
    return AdminPayoutItem(
      id: map['id']?.toString() ?? '',
      payoutReference: map['payout_reference']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      vendorName: map['vendor_name']?.toString() ?? 'Vendor',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'SLE',
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'pending',
      destinationType: map['destination_type']?.toString() ?? 'mobile_money',
      destinationProvider: map['destination_provider']?.toString() ?? '',
      destinationAccountNumber:
          map['destination_account_number']?.toString() ?? '',
      destinationAccountName:
          map['destination_account_name']?.toString() ?? '',
      disbursementMethod: map['disbursement_method']?.toString() ?? 'manual',
      providerReference: map['provider_reference']?.toString(),
      failureReason: map['failure_reason']?.toString(),
      adminNotes: map['admin_notes']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
    );
  }

  final String id;
  final String payoutReference;
  final String vendorId;
  final String vendorName;
  final double amount;
  final String currency;
  final double fee;
  final String status;
  final String destinationType;
  final String destinationProvider;
  final String destinationAccountNumber;
  final String destinationAccountName;
  final String disbursementMethod;
  final String? providerReference;
  final String? failureReason;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isPending => status == 'pending' || status == 'approved';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';

  /// Masked account number to protect sensitive financial identifiers in logs and UI.
  String get maskedAccountNumber {
    final clean = destinationAccountNumber.trim();
    if (clean.length <= 4) return '••••';
    final suffix = clean.substring(clean.length - 4);
    final prefix = clean.startsWith('+232') ? '+232 ' : '';
    return '$prefix•••• •••• $suffix';
  }

  String get formattedAmount => 'SLE ${amount.toStringAsFixed(2)}';

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}
