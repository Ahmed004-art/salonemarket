// SaloneMarket - main.dart
// NOTE: FlutterFlow will generate its own main.dart on export.
// This file establishes the structural contract and is used for manual Flutter development.
// When integrating FlutterFlow, compare carefully before replacing this file.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConstants.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
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
  runApp(const SaloneMarketApp());
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
