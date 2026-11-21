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

/// Customer and vendor sign-in screen.
///
/// Handles user credentials, form validation, password visibility toggling,
/// loading feedback, error banners, and password recovery routing.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    // Clear any previous error
    final authNotifier = context.read<AuthNotifier>();
    authNotifier.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await authNotifier.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go(Routes.home);
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
                  title: 'Welcome back',
                  subtitle: 'Sign in to access your orders, cart, and saved vendors.',
                  badgeText: 'SaloneMarket Auth',
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

                // Password field
                AuthTextField(
                  label: 'Password',
                  hintText: 'Enter your password',
                  controller: _passwordController,
                  validator: Validators.validatePassword,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignIn(),
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
                const SizedBox(height: AppSpacing.sm),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(Routes.forgotPassword),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      foregroundColor: SaloneMarketTheme.primary,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Sign In Button
                AuthButton(
                  text: 'Sign In',
                  onPressed: isLoading ? null : _handleSignIn,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Switch to Register
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: SaloneMarketTheme.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(Routes.register),
                        style: TextButton.styleFrom(
                          foregroundColor: SaloneMarketTheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                        child: Text(
                          'Create one',
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
