// SaloneMarket - main.dart
// NOTE: FlutterFlow will generate its own main.dart on export.
// This file establishes the structural contract and is used for manual Flutter development.
// When integrating FlutterFlow, compare carefully before replacing this file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/address/presentation/controllers/address_notifier.dart';
import 'features/admin/presentation/controllers/admin_notifier.dart';
import 'features/admin/presentation/controllers/admin_payout_notifier.dart';
import 'features/auth/presentation/controllers/auth_notifier.dart';
import 'features/cart/presentation/controllers/cart_notifier.dart';
import 'features/checkout/presentation/controllers/checkout_notifier.dart';
import 'features/marketplace/presentation/controllers/marketplace_notifier.dart';
import 'features/notifications/presentation/controllers/notifications_notifier.dart';
import 'features/orders/presentation/controllers/customer_orders_notifier.dart';
import 'features/vendor/presentation/controllers/vendor_notifier.dart';
import 'features/vendor/presentation/controllers/vendor_payout_notifier.dart';
import 'features/wishlist/presentation/controllers/wishlist_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface any layout or build error directly on the screen in big red text
  // instead of silently failing to a blank screen
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [FLUTTER CRITICAL ERROR] ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.red, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Rendering Error Detected',
                      style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: SelectableText(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  details.stack.toString(),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  if (AppConstants.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.supabaseAnonKey,
    );
  } else {
    debugPrint(
      '⚠️ [SaloneMarket] Supabase credentials not found.\n'
      'Run the app with configuration injected:\n'
      '  flutter run --dart-define-from-file=../supabase.dev.json\n'
      'or:\n'
      '  flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n',
    );
  }

  final authNotifier = AuthNotifier();
  final cartNotifier = CartNotifier();
  // Wire cart isolation: auth transitions update the cart's user scope (Finding 3 fix)
  authNotifier.setCartNotifier(cartNotifier);
  AppRouter.setAuthNotifier(authNotifier);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: authNotifier),
        ChangeNotifierProvider<MarketplaceNotifier>(
          create: (_) => MarketplaceNotifier(),
        ),
        ChangeNotifierProvider<CartNotifier>.value(value: cartNotifier),
        ChangeNotifierProvider<AddressNotifier>(
          create: (_) => AddressNotifier(),
        ),
        ChangeNotifierProvider<CheckoutNotifier>(
          create: (_) => CheckoutNotifier(),
        ),
        ChangeNotifierProvider<VendorNotifier>(
          create: (_) => VendorNotifier(),
        ),
        ChangeNotifierProvider<VendorPayoutNotifier>(
          create: (_) => VendorPayoutNotifier(),
        ),
        ChangeNotifierProvider<AdminNotifier>(
          create: (_) => AdminNotifier(),
        ),
        ChangeNotifierProvider<AdminPayoutNotifier>(
          create: (_) => AdminPayoutNotifier(),
        ),
        ChangeNotifierProvider<CustomerOrdersNotifier>(
          create: (_) => CustomerOrdersNotifier(),
        ),
        ChangeNotifierProvider<NotificationsNotifier>(
          create: (_) => NotificationsNotifier(),
        ),
        ChangeNotifierProvider<WishlistNotifier>(
          create: (_) => WishlistNotifier(),
        ),
      ],
      child: const SaloneMarketApp(),
    ),
  );
}

class SaloneMarketApp extends StatelessWidget {
  const SaloneMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: SaloneMarketTheme.lightTheme,
      darkTheme: SaloneMarketTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
