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
import 'features/auth/presentation/controllers/auth_notifier.dart';
import 'features/cart/presentation/controllers/cart_notifier.dart';
import 'features/checkout/presentation/controllers/checkout_notifier.dart';
import 'features/marketplace/presentation/controllers/marketplace_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
