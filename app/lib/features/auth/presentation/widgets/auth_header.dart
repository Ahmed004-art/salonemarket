import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Editorial header banner for authentication screens.
///
/// Features:
/// - SaloneMarket crest/badge with Sierra Leone Amber warmth
/// - Screen title in Plus Jakarta Sans (26px, bold)
/// - Subtitle in DM Sans (14px, muted)
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeText,
  });

  final String title;
  final String subtitle;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand icon / badge
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SaloneMarketTheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: SaloneMarketTheme.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'SM',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SaloneMarketTheme.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: SaloneMarketTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  badgeText!,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Screen title
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: SaloneMarketTheme.primary,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),

        // Subtitle
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: SaloneMarketTheme.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
