/// Authoritative financial summary for vendor earnings and balances.
class VendorPayoutSummary {
  const VendorPayoutSummary({
    required this.vendorId,
    required this.currency,
    required this.totalEarned,
    required this.totalPaidOut,
    required this.pendingPayout,
    required this.availableBalance,
  });

  factory VendorPayoutSummary.fromMap(Map<String, dynamic> map) {
    return VendorPayoutSummary(
      vendorId: map['vendor_id']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'SLE',
      totalEarned: (map['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalPaidOut: (map['total_paid_out'] as num?)?.toDouble() ?? 0.0,
      pendingPayout: (map['pending_payout'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (map['available_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String vendorId;
  final String currency;
  final double totalEarned;
  final double totalPaidOut;
  final double pendingPayout;
  final double availableBalance;

  String get formattedAvailable => 'SLE ${availableBalance.toStringAsFixed(2)}';
  String get formattedTotalEarned => 'SLE ${totalEarned.toStringAsFixed(2)}';
  String get formattedTotalPaidOut => 'SLE ${totalPaidOut.toStringAsFixed(2)}';
  String get formattedPending => 'SLE ${pendingPayout.toStringAsFixed(2)}';
}

/// Registered payout account destination for a merchant.
class VendorPayoutDestination {
  const VendorPayoutDestination({
    required this.id,
    required this.vendorId,
    required this.type,
    required this.provider,
    required this.accountNumber,
    required this.accountName,
    required this.isDefault,
    required this.isVerified,
    required this.createdAt,
  });

  factory VendorPayoutDestination.fromMap(Map<String, dynamic> map) {
    return VendorPayoutDestination(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'mobile_money',
      provider: map['provider']?.toString() ?? 'orange_money',
      accountNumber: map['account_number']?.toString() ?? '',
      accountName: map['account_name']?.toString() ?? '',
      isDefault: map['is_default'] == true,
      isVerified: map['is_verified'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String vendorId;
  final String type; // 'mobile_money' or 'bank_account'
  final String provider; // 'orange_money', 'afrimoney', bank name
  final String accountNumber;
  final String accountName;
  final bool isDefault;
  final bool isVerified;
  final DateTime createdAt;

  String get providerDisplayName {
    switch (provider) {
      case 'orange_money':
        return 'Orange Money';
      case 'afrimoney':
        return 'AfriMoney';
      case 'slcb':
        return 'Sierra Leone Commercial Bank';
      case 'rokel':
        return 'Rokel Commercial Bank';
      case 'gtbank':
        return 'Guaranty Trust Bank';
      default:
        return provider.toUpperCase();
    }
  }

  /// Masked account number to protect sensitive financial identifiers in logs and UI.
  String get maskedAccountNumber {
    final clean = accountNumber.trim();
    if (clean.length <= 4) return '••••';
    final suffix = clean.substring(clean.length - 4);
    final prefix = clean.startsWith('+232') ? '+232 ' : '';
    return '$prefix•••• •••• $suffix';
  }
}

/// Payout request record tracking outbound disbursement.
class VendorPayout {
  const VendorPayout({
    required this.id,
    required this.payoutReference,
    required this.vendorId,
    required this.amount,
    required this.currency,
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

  factory VendorPayout.fromMap(Map<String, dynamic> map) {
    return VendorPayout(
      id: map['id']?.toString() ?? '',
      payoutReference: map['payout_reference']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'SLE',
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
  final double amount;
  final String currency;
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

  String get formattedAmount => 'SLE ${amount.toStringAsFixed(2)}';

  /// Masked destination account number protecting sensitive information.
  String get maskedAccountNumber {
    final clean = destinationAccountNumber.trim();
    if (clean.length <= 4) return '••••';
    final suffix = clean.substring(clean.length - 4);
    final prefix = clean.startsWith('+232') ? '+232 ' : '';
    return '$prefix•••• •••• $suffix';
  }

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}

/// Immutable ledger entry tracking credits and debits to vendor balance.
class VendorLedgerEntry {
  const VendorLedgerEntry({
    required this.id,
    required this.vendorId,
    this.vendorOrderId,
    this.customerOrderId,
    this.payoutId,
    required this.type,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.currency,
    required this.reference,
    this.description,
    required this.createdAt,
  });

  factory VendorLedgerEntry.fromMap(Map<String, dynamic> map) {
    return VendorLedgerEntry(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      vendorOrderId: map['vendor_order_id']?.toString(),
      customerOrderId: map['customer_order_id']?.toString(),
      payoutId: map['payout_id']?.toString(),
      type: map['type']?.toString() ?? 'order_credit',
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0.05,
      commissionAmount: (map['commission_amount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'SLE',
      reference: map['reference']?.toString() ?? '',
      description: map['description']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String vendorId;
  final String? vendorOrderId;
  final String? customerOrderId;
  final String? payoutId;
  final String type;
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final String currency;
  final String reference;
  final String? description;
  final DateTime createdAt;

  bool get isCredit => netAmount > 0;
  String get formattedNet =>
      '${isCredit ? '+' : ''}SLE ${netAmount.toStringAsFixed(2)}';
}
