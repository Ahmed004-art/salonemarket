import 'package:flutter/material.dart';

/// Spacing scale for SaloneMarket UI.
// ignore_for_file: avoid_classes_with_only_static_members
class AppSpacing {
  static const double xxs = 2.0;
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
  static const double small = 6.0;
  static const double medium = 10.0;
  static const double large = 14.0;
  static const double xl = 20.0;
  static const double pill = 100.0;
}

/// Pre-defined shadow styles for SaloneMarket UI.
class AppShadows {
  /// Subtle card shadow — crisp, low-opacity forest-tinted elevation.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A123C35),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  /// Elevated shadow for floating bars, sticky CTAs, and bottom sheets.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14123C35),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Stronger shadow for modals and dialogs.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1F123C35),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];
}
