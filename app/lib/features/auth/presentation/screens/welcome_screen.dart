import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/auth_button.dart';

/// The initial landing screen greeting new and returning shoppers.
///
/// Introduces SaloneMarket's value proposition with editorial typography,
/// Sierra Leone commerce identity, and clear entry points.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppSpacing.lg * 2),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),

                      // Brand Emblem
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: SaloneMarketTheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: SaloneMarketTheme.accent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'SM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: SaloneMarketTheme.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Sierra Leone Tagline Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SaloneMarketTheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: SaloneMarketTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SaloneMarketTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Sierra Leone Mobile Commerce',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: SaloneMarketTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Editorial Headline
                      Text(
                        'Direct from\nlocal vendors\nto your door.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: SaloneMarketTheme.primary,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Subtitle
                      Text(
                        'Connect with trusted merchants in Freetown, Bo, Kenema, Makeni, and across Sierra Leone. Authentic products, fair pricing, and clear tracking.',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: SaloneMarketTheme.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Value propositions
                      _buildPillarItem(
                        icon: Icons.storefront_outlined,
                        title: 'Verified Local Sellers',
                        subtitle: 'Supporting Sierra Leonean entrepreneurs',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildPillarItem(
                        icon: Icons.payments_outlined,
                        title: 'Transparent Leone (Le) Pricing',
                        subtitle: 'No hidden currency conversion fees',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildPillarItem(
                        icon: Icons.local_shipping_outlined,
                        title: 'Vendor-Direct Fulfilment',
                        subtitle: 'Split orders and clear milestone tracking',
                      ),

                      const Spacer(flex: 2),
                      const SizedBox(height: AppSpacing.xl),

                      // Action CTAs
                      AuthButton(
                        text: 'Get Started (Create Account)',
                        onPressed: () => context.push(Routes.register),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      AuthButton(
                        text: 'Sign In to Account',
                        onPressed: () => context.push(Routes.login),
                        variant: AuthButtonVariant.secondary,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Guest browse link
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(Routes.home),
                          style: TextButton.styleFrom(
                            foregroundColor: SaloneMarketTheme.muted,
                          ),
                          child: Text(
                            'Continue as Guest',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPillarItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SaloneMarketTheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: SaloneMarketTheme.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: SaloneMarketTheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SaloneMarketTheme.primary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: SaloneMarketTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
