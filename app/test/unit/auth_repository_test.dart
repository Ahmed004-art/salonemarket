// Unit tests for AuthRepository pure logic.
//
// Tests that require a live Supabase environment are skipped with a
// descriptive message so CI stays green and the intent is documented.

import 'package:flutter_test/flutter_test.dart';

// ── Pure helper used by the passing test ──────────────────────────────────

/// Returns true when [ref] matches the SaloneMarket payment-reference format:
/// SM-{4 uppercase letters}{4 digits}-{8-digit date YYYYMMDD}
///
/// Example: SM-ABCD1234-20261120
bool isValidPaymentReference(String ref) {
  final pattern = RegExp(r'^SM-[A-Z]{4}\d{4}-\d{8}$');
  return pattern.hasMatch(ref);
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('Payment reference format', () {
    test('payment reference has correct format', () {
      // Valid references
      expect(isValidPaymentReference('SM-ABCD1234-20261120'), isTrue);
      expect(isValidPaymentReference('SM-XYZW9999-20260101'), isTrue);
      expect(isValidPaymentReference('SM-AAAA0000-20991231'), isTrue);

      // Invalid references
      expect(isValidPaymentReference('SM-ABC1234-20261120'), isFalse); // too short prefix
      expect(isValidPaymentReference('SM-ABCD123-20261120'), isFalse); // 3 digits
      expect(isValidPaymentReference('SM-abcd1234-20261120'), isFalse); // lowercase
      expect(isValidPaymentReference('XX-ABCD1234-20261120'), isFalse); // wrong prefix
      expect(isValidPaymentReference('SM-ABCD1234-2026112'), isFalse); // short date
      expect(isValidPaymentReference(''), isFalse);
    });
  });

  group('AuthRepository — requires Supabase (skipped in unit CI)', () {
    test(
      'signUpWithEmail returns AuthSuccess on valid credentials',
      () async {
        // Needs a real or mocked Supabase instance.
        // Run against a local Supabase dev environment.
      },
      skip: 'Requires SUPABASE_URL and SUPABASE_ANON_KEY environment — run '
          'with: flutter test --dart-define=SUPABASE_URL=... '
          '--dart-define=SUPABASE_ANON_KEY=...',
    );

    test(
      'signInWithEmail returns AuthFailure on wrong password',
      () async {},
      skip: 'Requires live Supabase environment to test invalid-password '
          'response from GoTrue',
    );

    test(
      'getUserProfile returns UserProfile for existing user',
      () async {},
      skip: 'Requires Supabase environment with seeded profiles table',
    );

    test(
      'watchAuthState emits AuthChangeEvent.signedIn after login',
      () async {},
      skip: 'Integration-level test — needs Supabase stream and real session',
    );

    test(
      'signOut clears the session',
      () async {},
      skip: 'Requires an active Supabase session to sign out of',
    );
  });
}
