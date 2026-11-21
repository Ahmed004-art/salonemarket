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

/// Customer account registration screen.
///
/// Features:
/// - Full Name, Email, Phone (optional), and Password fields
/// - Live password strength guidance
/// - Password and Confirm Password match verification
/// - Dual password visibility controls
/// - Seamless transition to login or verification
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final authNotifier = context.read<AuthNotifier>();
    authNotifier.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms of Service to create an account.'),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
      return;
    }

    final success = await authNotifier.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    if (success && mounted) {
      if (authNotifier.isAuthenticated) {
        context.go(Routes.home);
      } else {
        // Verification email sent
        context.push(
          Routes.emailVerification,
          extra: _emailController.text.trim(),
        );
      }
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
              context.go(Routes.splash);
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(
                  title: 'Create Account',
                  subtitle: 'Join SaloneMarket to shop directly from Sierra Leone vendors.',
                  badgeText: 'New Shopper',
                ),
                const SizedBox(height: AppSpacing.xl),

                // Error Banner
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              height: 1.4,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: SaloneMarketTheme.error,
                          ),
                          onPressed: authNotifier.clearError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Full Name field
                AuthTextField(
                  label: 'Full Name',
                  hintText: 'e.g., Alie Kamara',
                  controller: _fullNameController,
                  validator: Validators.validateFullName,
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Email field
                AuthTextField(
                  label: 'Email address',
                  hintText: 'e.g., alie.kamara@example.com',
                  controller: _emailController,
                  validator: Validators.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(
                    Icons.mail_outline,
                    size: 20,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Phone field (optional)
                AuthTextField(
                  label: 'Phone number (optional)',
                  hintText: 'e.g., 076 123456 or +232 76 123456',
                  controller: _phoneController,
                  validator: Validators.validatePhone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password field
                AuthTextField(
                  label: 'Password',
                  hintText: 'Minimum 8 characters (letters & numbers)',
                  controller: _passwordController,
                  validator: Validators.validatePassword,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: SaloneMarketTheme.muted,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: SaloneMarketTheme.muted,
                    ),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Confirm Password field
                AuthTextField(
                  label: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  validator: (v) => Validators.validateConfirmPassword(
                    v,
                    _passwordController.text,
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  prefixIcon: const Icon(
                    Icons.lock_reset_outlined,
                    size: 20,
                    color: SaloneMarketTheme.muted,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: SaloneMarketTheme.muted,
                    ),
                    tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Terms and Conditions checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: SaloneMarketTheme.accent,
                        checkColor: SaloneMarketTheme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'By creating an account, you agree to SaloneMarket Terms of Service and Privacy Policy.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: SaloneMarketTheme.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                AuthButton(
                  text: 'Create Account',
                  onPressed: isLoading ? null : _handleRegister,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Switch to Sign In
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: SaloneMarketTheme.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(Routes.login),
                        style: TextButton.styleFrom(
                          foregroundColor: SaloneMarketTheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SaloneMarketTheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
