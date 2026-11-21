import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/auth_button.dart';

/// Screen guiding the user to verify their email address upon registration.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({
    super.key,
    this.email,
  });

  /// The email address to which the verification link was dispatched.
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: SaloneMarketTheme.primary,
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.login);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 44,
                    color: Color(0xFFC98410),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: SaloneMarketTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  email != null && email!.isNotEmpty
                      ? 'We sent a verification link to\n$email'
                      : 'We sent a verification link to your email address.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: SaloneMarketTheme.muted,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SaloneMarketTheme.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: SaloneMarketTheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Click the link in the message to activate your account. If you do not see it within a few minutes, please check your spam folder.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: SaloneMarketTheme.muted,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              AuthButton(
                text: 'Return to Sign In',
                onPressed: () {
                  context.go(Routes.login);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  context.go(Routes.register);
                },
                child: Text(
                  'Need to change your email? Sign up again',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: SaloneMarketTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
