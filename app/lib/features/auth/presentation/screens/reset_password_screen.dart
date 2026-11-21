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

/// Screen where user enters a new password after following a recovery link.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _resetComplete = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    final authNotifier = context.read<AuthNotifier>();
    authNotifier.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await authNotifier.updatePassword(
      newPassword: _passwordController.text,
    );

    if (success && mounted) {
      setState(() {
        _resetComplete = true;
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
          child: _resetComplete
              ? _buildSuccessView()
              : _buildFormView(isLoading, errorMessage),
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
            title: 'Set New Password',
            subtitle:
                'Create a strong, unique password to secure your SaloneMarket account.',
            badgeText: 'Security',
          ),
          const SizedBox(height: AppSpacing.xl),

          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: SaloneMarketTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SaloneMarketTheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: SaloneMarketTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: SaloneMarketTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          AuthTextField(
            label: 'New Password',
            hintText: '••••••••',
            controller: _passwordController,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: AppSpacing.md),

          AuthTextField(
            label: 'Confirm New Password',
            hintText: '••••••••',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (val) => Validators.validateConfirmPassword(
              val,
              _passwordController.text,
            ),
            onFieldSubmitted: (_) => _handleUpdatePassword(),
          ),
          const SizedBox(height: AppSpacing.xl),

          AuthButton(
            text: 'Update Password',
            isLoading: isLoading,
            onPressed: _handleUpdatePassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: SaloneMarketTheme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 48,
              color: SaloneMarketTheme.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Password Updated',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: SaloneMarketTheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Your password has been changed successfully. You can now sign in with your new credentials.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: SaloneMarketTheme.muted,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AuthButton(
          text: 'Sign In to Your Account',
          onPressed: () {
            context.go(Routes.login);
          },
        ),
      ],
    );
  }
}
