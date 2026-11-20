import 'package:flutter/material.dart';

/// Spacing scale for SaloneMarket UI.
///
/// Use these constants instead of hard-coded pixel values to keep
/// the design consistent and easy to adjust globally.
// ignore_for_file: avoid_classes_with_only_static_members
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Border-radius scale for SaloneMarket UI.
class AppRadius {
  static const double small = 4.0;
  static const double medium = 8.0;
  static const double large = 12.0;
  static const double pill = 100.0;
}

/// Pre-defined shadow styles for SaloneMarket UI.
class AppShadows {
  /// Subtle card shadow — use for elevated cards and bottom sheets.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D1A1A2E), // primary @ 5 % opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Stronger shadow for modals and dialogs.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1A1A1A2E), // primary @ 10 % opacity
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
