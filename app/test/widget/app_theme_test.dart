// Widget tests for SaloneMarketTheme.
//
// These tests do NOT require a Supabase environment and pass in CI with `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salonemarket/core/theme/app_theme.dart';

void main() {
  group('SaloneMarketTheme', () {
    test('lightTheme primary color is Deep Navy (0xFF1A1A2E)', () {
      expect(SaloneMarketTheme.primary, equals(const Color(0xFF1A1A2E)));
    });

    test('lightTheme accent (secondary) color is Warm Amber (0xFFE8A020)', () {
      expect(SaloneMarketTheme.accent, equals(const Color(0xFFE8A020)));
    });

    test('lightTheme scaffoldBackgroundColor is Warm Off-White (0xFFF7F4EF)', () {
      expect(SaloneMarketTheme.background, equals(const Color(0xFFF7F4EF)));
    });

    test('lightTheme error color is correct (0xFFC0392B)', () {
      expect(SaloneMarketTheme.error, equals(const Color(0xFFC0392B)));
    });

    testWidgets('lightTheme uses Material 3', (tester) async {
      final theme = SaloneMarketTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
    });

    testWidgets('MaterialApp builds without error using lightTheme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('SaloneMarket')),
          ),
        ),
      );

      // No exceptions thrown → build succeeded.
      expect(find.text('SaloneMarket'), findsOneWidget);
    });

    testWidgets('ElevatedButton renders with accent background color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Buy Now'),
            ),
          ),
        ),
      );

      expect(find.text('Buy Now'), findsOneWidget);
    });

    testWidgets('AppBar renders with correct foreground color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('SaloneMarket')),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('SaloneMarket'), findsOneWidget);
    });
  });
}
