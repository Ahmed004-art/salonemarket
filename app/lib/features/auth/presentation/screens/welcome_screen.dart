import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_buttons.dart';
import '../../../../core/widgets/salone_logo.dart';
import '../../../../core/widgets/salone_motion.dart';

/// Welcome screen for returning unauthenticated users.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneColors.background,
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
                      const SizedBox(height: AppSpacing.sm),
                      const SaloneLogo(
                        variant: SaloneLogoVariant.full,
                        markSize: 42,
                        showTagline: true,
                      ),
                      const Spacer(),

                      // Editorial Hero Panel
                      SaloneFadeIn(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: SaloneColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: AppShadows.elevated,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: SaloneColors.gold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Trusted Sierra Leone Commerce',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: SaloneColors.cream,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Direct from local vendors to your door.',
                                style: GoogleFonts.manrope(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Shop verified stores across Freetown, Bo, Kenema, and Makeni with Monime mobile-money protection.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: SaloneColors.cream.withValues(alpha: 0.85),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Actions
                      SalonePrimaryButton(
                        label: 'Sign In',
                        icon: Icons.login_rounded,
                        onPressed: () => context.push(Routes.login),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SaloneSecondaryButton(
                        label: 'Create Account',
                        onPressed: () => context.push(Routes.register),
                        borderColor: SaloneColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: SaloneGhostButton(
                          label: 'Browse Marketplace as Guest',
                          icon: Icons.storefront_outlined,
                          onPressed: () => context.go(Routes.home),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
}
