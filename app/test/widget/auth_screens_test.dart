import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:salonemarket/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:salonemarket/features/auth/presentation/screens/login_screen.dart';
import 'package:salonemarket/features/auth/presentation/screens/register_screen.dart';
import 'package:salonemarket/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:salonemarket/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:salonemarket/features/auth/presentation/screens/welcome_screen.dart';

Widget _createTestWidget({
  required Widget child,
  AuthNotifier? notifier,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthNotifier>.value(
        value: notifier ?? AuthNotifier(),
      ),
    ],
    child: MaterialApp(
      theme: SaloneMarketTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('WelcomeScreen Widget Tests', () {
    testWidgets('renders brand tagline, headline, and action buttons', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const WelcomeScreen()));

      expect(find.text('Sierra Leone Mobile Commerce'), findsOneWidget);
      expect(find.text('Direct from\nlocal vendors\nto your door.'), findsOneWidget);
      expect(find.text('Get Started (Create Account)'), findsOneWidget);
      expect(find.text('Sign In to Account'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('renders email, password fields and sign in button', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const LoginScreen()));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create one'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitted with empty fields', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const LoginScreen()));

      final signInButtons = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButtons);
      await tester.pump();

      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('toggles password visibility icon on tap', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const LoginScreen()));

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders all registration fields and terms checkbox', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const RegisterScreen()));

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Phone number (optional)'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.textContaining('Terms of Service and Privacy Policy'),
        findsOneWidget,
      );
    });

    testWidgets('validates required fields on empty submit', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const RegisterScreen()));

      final submitBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('renders email field and send button', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const ForgotPasswordScreen()));

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('validates empty email field', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const ForgotPasswordScreen()));

      final button = find.widgetWithText(ElevatedButton, 'Send Reset Link');
      await tester.tap(button);
      await tester.pump();

      expect(find.text('Please enter your email address'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('renders new password and confirmation fields', (tester) async {
      await tester.pumpWidget(_createTestWidget(child: const ResetPasswordScreen()));

      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });
  });

  group('VerifyEmailScreen Widget Tests', () {
    testWidgets('renders instructions and destination email', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          child: const VerifyEmailScreen(email: 'amadu@example.sl'),
        ),
      );

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.textContaining('amadu@example.sl'), findsOneWidget);
      expect(find.text('Return to Sign In'), findsOneWidget);
    });
  });
}
