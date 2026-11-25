import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/payment/presentation/screens/receipt_screen.dart';

void main() {
  group('ReceiptScreen Widget Tests', () {
    testWidgets('renders receipt details correctly when data is provided', (tester) async {
      final mockData = <String, dynamic>{
        'receipt_number': 'SM-RCP-TEST1234',
        'generated_at': '2026-11-22T10:00:00Z',
        'is_simulated': true,
        'order': {
          'id': 'ord-12345678',
          'status': 'confirmed',
          'payment_status': 'paid',
        },
        'line_items_by_vendor': [
          {
            'vendor': {'shop_name': 'Sierra Supermarket'},
            'items': [
              {
                'product_name': 'Jollof Rice (50kg)',
                'quantity': 1,
                'unit_price': 500.0,
                'line_total': 500.0,
              }
            ],
          }
        ],
        'totals': {
          'subtotal': 500.0,
          'delivery_fee': 25.0,
          'platform_fee': 10.0,
          'total': 535.0,
          'currency': 'SLE',
        },
        'transaction': {
          'reference': 'TX-SIM-998877',
          'status': 'succeeded',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: ReceiptScreen(
            orderId: 'ord-12345678',
            initialData: mockData,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Order Receipt'), findsOneWidget);
      expect(find.text('Payment Settled'), findsOneWidget);
      expect(find.text('SM-RCP-TEST1234'), findsOneWidget);
      expect(find.text('TX-SIM-998877'), findsOneWidget);
      expect(find.text('CONFIRMED & PAID'), findsOneWidget);
      expect(find.text('Sierra Supermarket'), findsOneWidget);
      expect(find.text('1 × Jollof Rice (50kg)'), findsOneWidget);
      expect(find.text('SLE 535.0'), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
      expect(find.textContaining('simulated transaction receipt'), findsOneWidget);
    });

    testWidgets('renders fallback state when receipt data is unavailable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: const ReceiptScreen(
            orderId: 'ord-unavailable-000',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Order Receipt'), findsOneWidget);
      expect(find.text('Receipt Unavailable'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
    });
  });
}
