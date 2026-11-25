import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../payment/presentation/controllers/payment_notifier.dart';
import '../../data/models/checkout_result_model.dart';

/// Screen displayed after successful checkout preparation and order registration.
/// Supports live Monime Mobile Money (Orange Money & AfriMoney) payment initiation,
/// USSD approval instructions, and automatic settlement polling.
class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.checkoutResult,
    this.paymentNotifier,
  });

  final String orderId;
  final CheckoutResult? checkoutResult;
  final PaymentNotifier? paymentNotifier;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  late final PaymentNotifier _notifier;
  bool _internalNotifier = false;

  final TextEditingController _phoneController = TextEditingController();
  String _selectedProvider = 'orange_money';
  String? _validationError;
  late String _idempotencyKey;
  Timer? _pollTimer;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _generateIdempotencyKey();
    if (widget.paymentNotifier != null) {
      _notifier = widget.paymentNotifier!;
    } else {
      _notifier = PaymentNotifier();
      _internalNotifier = true;
    }
    _notifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notifier.removeListener(_onNotifierChanged);
    _phoneController.dispose();
    if (_internalNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  String _generateIdempotencyKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _onNotifierChanged() {
    if (!mounted) return;
    if (_notifier.isPendingOrTimeout) {
      _startPolling();
    } else if (_notifier.isSucceeded || _notifier.isFailed) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    if (_pollTimer?.isActive ?? false) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_notifier.isPendingOrTimeout) {
        _pollTimer?.cancel();
        return;
      }
      _notifier.refreshOrderStatus(widget.orderId);
    });
  }

  Future<void> _handleManualStatusCheck() async {
    setState(() => _isCheckingStatus = true);
    await _notifier.refreshOrderStatus(widget.orderId);
    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _handlePayment() async {
    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length < 8) {
      setState(() {
        _validationError =
            'Enter a valid Sierra Leone Mobile Money number (e.g. 076123456).';
      });
      return;
    }

    setState(() => _validationError = null);

    // If retrying after a failure, generate a fresh idempotency key so a new
    // Monime payment code is created cleanly.
    if (_notifier.isFailed) {
      _idempotencyKey = _generateIdempotencyKey();
    }

    final result = widget.checkoutResult;
    await _notifier.processPayment(
      customerOrderId: widget.orderId,
      method: PaymentMethod.mobileMoney,
      provider: _selectedProvider,
      phoneNumber: phone,
      idempotencyKey: _idempotencyKey,
      expectedAmount: result != null && result.total > 0 ? result.total : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.checkoutResult;
    final totalText =
        result != null && result.total > 0 ? result.formattedTotal : null;
    final vendorOrderCount = result?.vendorOrderIds.length ?? 0;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.surface,
      appBar: AppBar(
        title: Text(
          'Order Placed',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _notifier,
          builder: (context, _) {
            final isPaid = _notifier.isSucceeded;
            final isProcessing = _notifier.isProcessing;
            final isFailed = _notifier.isFailed;
            final isPending = _notifier.isPendingOrTimeout;

            String statusText = 'Status: Pending Payment';
            Color statusColor = SaloneMarketTheme.accent;

            if (isPaid) {
              statusText = 'Status: Confirmed & Paid';
              statusColor = Colors.green.shade700;
            } else if (isFailed) {
              statusText = 'Status: Payment Failed';
              statusColor = Colors.red.shade700;
            } else if (isPending) {
              statusText = 'Status: Payment Processing';
              statusColor = Colors.orange.shade800;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Success / Payment Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isFailed
                            ? Colors.red.shade50
                            : isPending
                                ? Colors.amber.shade50
                                : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFailed
                            ? Icons.error_outline_rounded
                            : isPending
                                ? Icons.hourglass_top_rounded
                                : Icons.check_circle_rounded,
                        size: 52,
                        color: isFailed
                            ? Colors.red.shade600
                            : isPending
                                ? Colors.amber.shade800
                                : Colors.green.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Status
                  Text(
                    isPaid ? 'Payment Confirmed!' : 'Order Registered!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: SaloneMarketTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SaloneMarketTheme.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer Order ID',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: SaloneMarketTheme.muted,
                              ),
                            ),
                            Text(
                              widget.orderId.length > 12
                                  ? '${widget.orderId.substring(0, 8)}...'
                                  : widget.orderId,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: SaloneMarketTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        if (vendorOrderCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vendor Orders Generated',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: SaloneMarketTheme.muted,
                                ),
                              ),
                              Text(
                                '$vendorOrderCount order(s)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: SaloneMarketTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (totalText != null) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Authoritative Total',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                totalText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: SaloneMarketTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_notifier.lastResult?.transactionReference != null) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transaction Ref',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: SaloneMarketTheme.muted,
                                ),
                              ),
                              Text(
                                _notifier.lastResult!.transactionReference!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: SaloneMarketTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mobile Money Selector & Phone Input (when awaiting initiation or retrying)
                  if (!isPaid && !isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SaloneMarketTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay with Monime Mobile Money',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: SaloneMarketTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildProviderChip(
                                  id: 'orange_money',
                                  label: 'Orange Money',
                                  icon: Icons.phone_android,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildProviderChip(
                                  id: 'afrimoney',
                                  label: 'AfriMoney',
                                  icon: Icons.account_balance_wallet_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: !isProcessing,
                            decoration: InputDecoration(
                              labelText: 'Mobile Money Phone Number',
                              hintText: 'e.g. 076 123 456 or +232 76 123 456',
                              prefixIcon: const Icon(Icons.dialpad),
                              errorText: _validationError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // USSD Approval Banner (Live Monime pending state)
                  if (_notifier.lastResult?.ussdCode != null && !isPaid) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: Colors.amber.shade900,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Approve via USSD on your phone',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: SelectableText(
                              _notifier.lastResult!.ussdCode!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                letterSpacing: 1.5,
                                color: SaloneMarketTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Dial this code on your Orange or Africell phone and enter your Mobile Money PIN. This screen updates automatically once confirmed.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_notifier.errorMessage != null &&
                      !isPaid &&
                      !isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _notifier.errorMessage!,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isPaid) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 20,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Payment verified by Monime. Your order has been confirmed with the vendor(s).',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Primary Action Button
                  if (!isPaid && !isPending) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFailed
                              ? Colors.red.shade700
                              : SaloneMarketTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isProcessing ? null : _handlePayment,
                        child: isProcessing
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                isFailed ? 'Retry Payment' : 'Pay Now',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Manual Check Status Button while awaiting USSD confirmation
                  if (isPending) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SaloneMarketTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed:
                            _isCheckingStatus ? null : _handleManualStatusCheck,
                        icon: _isCheckingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(
                          _isCheckingStatus
                              ? 'Checking Payment Status...'
                              : "I've Paid — Check Status",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // View Receipt Button (when payment is confirmed)
                  if (isPaid) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SaloneMarketTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          context.push(
                            Routes.receipt.replaceAll(':orderId', widget.orderId),
                          );
                        },
                        icon: const Icon(Icons.receipt_long, size: 20),
                        label: Text(
                          'View Order Receipt',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Return Home Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SaloneMarketTheme.primary,
                        side: const BorderSide(color: SaloneMarketTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => context.go(Routes.home),
                      child: Text(
                        'Continue Shopping',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProviderChip({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedProvider == id;
    return InkWell(
      onTap: () => setState(() => _selectedProvider = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? SaloneMarketTheme.primary.withValues(alpha: 0.08)
              : SaloneMarketTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? SaloneMarketTheme.primary
                : SaloneMarketTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? SaloneMarketTheme.primary
                  : SaloneMarketTheme.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? SaloneMarketTheme.primary
                      : SaloneMarketTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
