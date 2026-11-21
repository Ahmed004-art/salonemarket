import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Hero promotional banner carousel celebrating Sierra Leonean commerce.
class PromotionalCarousel extends StatelessWidget {
  const PromotionalCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            SaloneMarketTheme.primary,
            Color(0xFF252542),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SaloneMarketTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          // Decorative background accent circle
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SaloneMarketTheme.accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SIERRA LEONE SHOWCASE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: SaloneMarketTheme.onAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Direct from Local\nMerchants & Makers',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fair prices in SLE with verified sellers across Freetown, Bo, Kenema & Makeni.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: SaloneMarketTheme.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
