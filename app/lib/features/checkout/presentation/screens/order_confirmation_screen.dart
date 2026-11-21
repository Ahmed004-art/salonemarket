import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/checkout_result_model.dart';

/// Screen displayed after successful checkout preparation and order registration.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.checkoutResult,
  });

  final String orderId;
  final CheckoutResult? checkoutResult;

  @override
  Widget build(BuildContext context) {
    final result = checkoutResult;
    final totalText = result != null && result.total > 0
        ? result.formattedTotal
        : null;
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Title & Status
              Text(
                'Order Registered!',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: SaloneMarketTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: Pending Payment',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: SaloneMarketTheme.accent,
                ),
              ),
              const SizedBox(height: 16),

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
                          orderId.length > 12
                              ? '${orderId.substring(0, 8)}...'
                              : orderId,
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mobile Money Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: SaloneMarketTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mobile money integration (Orange Money & Afrimoney) will be completed in the next milestone.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Return Home Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaloneMarketTheme.primary,
                    foregroundColor: Colors.white,
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
        ),
      ),
    );
  }
}
