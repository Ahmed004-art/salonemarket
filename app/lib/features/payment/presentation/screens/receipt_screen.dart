import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/payment_repository.dart';

/// Screen displaying the official customer receipt for a settled order.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.orderId,
    this.repository,
    this.initialData,
  });

  final String orderId;
  final PaymentRepository? repository;
  final Map<String, dynamic>? initialData;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final PaymentRepository _repository;
  Map<String, dynamic>? _receiptData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PaymentRepository();
    if (widget.initialData != null) {
      _receiptData = widget.initialData;
      _isLoading = false;
    } else {
      _loadReceipt();
    }
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await _repository.getReceipt(customerOrderId: widget.orderId);

    if (!mounted) return;

    if (data != null) {
      setState(() {
        _receiptData = data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Could not load official receipt from server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.surface,
      appBar: AppBar(
        title: Text(
          'Order Receipt',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReceipt,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _receiptData == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: SaloneMarketTheme.muted),
            const SizedBox(height: 16),
            Text(
              'Receipt Unavailable',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: SaloneMarketTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}\n$_errorMessage',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: SaloneMarketTheme.muted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReceipt,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Return to Home'),
            ),
          ],
        ),
      );
    }

    final data = _receiptData!;
    final receiptNum = data['receipt_number'] as String? ?? 'SM-RCP-${widget.orderId.substring(0, 8).toUpperCase()}';
    final generatedAt = data['generated_at'] as String? ?? '';
    final isSimulated = data['is_simulated'] as bool? ?? true;
    final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
    final currency = totals['currency'] as String? ?? 'SLE';
    final totalAmount = totals['total'] != null ? totals['total'].toString() : '0.00';
    final subtotal = totals['subtotal'] != null ? totals['subtotal'].toString() : '0.00';
    final deliveryFee = totals['delivery_fee'] != null ? totals['delivery_fee'].toString() : '0.00';
    final platformFee = totals['platform_fee'] != null ? totals['platform_fee'].toString() : '0.00';

    final transaction = data['transaction'] as Map<String, dynamic>?;
    final txRef = transaction?['reference'] as String? ?? 'Pending';

    final vendorOrders = (data['line_items_by_vendor'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Receipt Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SaloneMarketTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  'Payment Settled',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  receiptNum,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: SaloneMarketTheme.accent,
                  ),
                ),
                if (generatedAt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    generatedAt,
                    style: GoogleFonts.dmSans(fontSize: 12, color: SaloneMarketTheme.muted),
                  ),
                ],
                const Divider(height: 28),
                _buildRow('Customer Order ID', widget.orderId.length > 12 ? '${widget.orderId.substring(0, 8)}...' : widget.orderId),
                const SizedBox(height: 8),
                _buildRow('Transaction Reference', txRef),
                const SizedBox(height: 8),
                _buildRow('Status', 'CONFIRMED & PAID', valueColor: Colors.green.shade800),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items by Vendor
          if (vendorOrders.isNotEmpty) ...[
            Text(
              'Purchased Items',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: SaloneMarketTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...vendorOrders.map((vo) {
              final vendor = (vo['vendor'] as Map<String, dynamic>?) ?? {};
              final shopName = vendor['shop_name'] as String? ?? 'Marketplace Vendor';
              final items = (vo['items'] as List<dynamic>?) ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      shopName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                    const Divider(height: 16),
                    ...items.map((item) {
                      final name = item['product_name'] as String? ?? 'Product';
                      final qty = item['quantity'] ?? 1;
                      final lineTotal = item['line_total'] != null ? item['line_total'].toString() : '0.00';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$qty × $name',
                                style: GoogleFonts.dmSans(fontSize: 13),
                              ),
                            ),
                            Text(
                              '$currency $lineTotal',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Payment Summary Card
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
                  'Payment Summary',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
                const Divider(height: 20),
                _buildRow('Subtotal', '$currency $subtotal'),
                const SizedBox(height: 6),
                _buildRow('Delivery Fee', '$currency $deliveryFee'),
                const SizedBox(height: 6),
                _buildRow('Platform Fee', '$currency $platformFee'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Paid',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                    Text(
                      '$currency $totalAmount',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Simulation Disclaimer Banner
          if (isSimulated)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This is a simulated transaction receipt. No real financial currency has been transferred.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Back to Shopping Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SaloneMarketTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.go(Routes.home),
            child: Text(
              'Continue Shopping',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 13, color: SaloneMarketTheme.muted),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? SaloneMarketTheme.primary,
          ),
        ),
      ],
    );
  }
}
