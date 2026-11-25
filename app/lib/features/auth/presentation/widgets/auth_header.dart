import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_logo.dart';
import '../../../../core/widgets/salone_motion.dart';

/// Editorial header banner for authentication screens.
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
    return SaloneFadeIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SaloneLogo(
                variant: SaloneLogoVariant.iconOnly,
                markSize: 44,
              ),
              if (badgeText != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: SaloneColors.cream,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: SaloneColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SaloneColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SaloneColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: SaloneColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
