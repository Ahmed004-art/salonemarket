import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_notifier.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';

/// Password recovery screen where the user requests a reset email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final authNotifier = context.read<AuthNotifier>();
    authNotifier.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await authNotifier.sendPasswordReset(
      email: _emailController.text,
    );

    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final isLoading = authNotifier.isLoading;
    final errorMessage = authNotifier.errorMessage;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: _emailSent ? _buildSuccessView() : _buildFormView(isLoading, errorMessage),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isLoading, String? errorMessage) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeader(
            title: 'Reset Password',
            subtitle: 'Enter your registered email address and we will send you instructions to reset your password.',
            badgeText: 'Recovery',
          ),
          const SizedBox(height: AppSpacing.xl),

          if (errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: SaloneMarketTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: SaloneMarketTheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: SaloneMarketTheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: SaloneMarketTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          AuthTextField(
            label: 'Email address',
            hintText: 'e.g., alie.kamara@example.com',
            controller: _emailController,
            validator: Validators.validateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleReset(),
            prefixIcon: const Icon(
              Icons.mail_outline,
              size: 20,
              color: SaloneMarketTheme.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AuthButton(
            text: 'Send Reset Link',
            onPressed: isLoading ? null : _handleReset,
            isLoading: isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: TextButton(
              onPressed: () => context.go(Routes.login),
              style: TextButton.styleFrom(
                foregroundColor: SaloneMarketTheme.primary,
              ),
              child: Text(
                'Remember your password? Sign in',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SaloneMarketTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: SaloneMarketTheme.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: SaloneMarketTheme.success.withValues(alpha: 0.3),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 28,
              color: SaloneMarketTheme.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(
          'Check your inbox',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: SaloneMarketTheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),

        Text(
          'We have dispatched a password reset link to ${_emailController.text.trim()}. Please open the link on this device to reset your password.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: SaloneMarketTheme.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        AuthButton(
          text: 'Return to Sign In',
          onPressed: () => context.go(Routes.login),
        ),
      ],
    );
  }
}
