import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';

/// Centralised brand colour tokens for SaloneMarket ("Premium Modern African Commerce").
class SaloneColors {
  SaloneColors._();

  static const Color primary = Color(0xFF123C35); // Forest green
  static const Color secondary = Color(0xFF0E8F6E); // Emerald green
  static const Color cream = Color(0xFFF5F2E9); // Light cream
  static const Color gold = Color(0xFFE7AD55); // Warm gold accent
  static const Color textPrimary = Color(0xFF202B28); // Main text
  static const Color textSecondary = Color(0xFF68756F); // Secondary text
  static const Color surface = Color(0xFFFFFFFF); // White surface
  static const Color background = Color(0xFFF7F8F5); // Subtle background
  static const Color surfaceContainer = Color(0xFFEEF2EF); // Tinted container
  static const Color border = Color(0xFFE1E6E2); // Crisp hairline border
  static const Color error = Color(0xFFC94C4C); // Error
  static const Color success = Color(0xFF23845B); // Success
  static const Color warning = Color(0xFFD98A2B); // Warning
  static const Color info = Color(0xFF1D6B87); // Info

  // Dark theme counterparts
  static const Color darkBackground = Color(0xFF0F1916);
  static const Color darkSurface = Color(0xFF162420);
  static const Color darkSurfaceContainer = Color(0xFF1E302B);
  static const Color darkBorder = Color(0xFF293F39);
  static const Color darkTextPrimary = Color(0xFFF2F5F3);
  static const Color darkTextSecondary = Color(0xFFA0AFA8);
}

/// SaloneMarket design system theme.
class SaloneMarketTheme {
  SaloneMarketTheme._();

  // ── Backward-compatible semantic aliases ──────────────────────────────────
  static const Color primary = SaloneColors.primary;
  static const Color secondary = SaloneColors.secondary;
  static const Color cream = SaloneColors.cream;
  static const Color accent = SaloneColors.gold;
  static const Color background = SaloneColors.background;
  static const Color surface = SaloneColors.surface;
  static const Color muted = SaloneColors.textSecondary;
  static const Color textSecondary = SaloneColors.textSecondary;
  static const Color textPrimary = SaloneColors.textPrimary;
  static const Color surfaceContainer = SaloneColors.surfaceContainer;
  static const Color success = SaloneColors.success;
  static const Color error = SaloneColors.error;
  static const Color vendorAccent = SaloneColors.secondary;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = SaloneColors.textPrimary;
  static const Color onBackground = SaloneColors.textPrimary;
  static const Color border = SaloneColors.border;
  static const Color cardBackground = SaloneColors.surface;

  // ── Typography helpers ────────────────────────────────────────────────────
  /// Manrope for prominent headings, titles, and numerical KPIs.
  static TextStyle headingStyle({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = SaloneColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Inter for body copy, labels, and interface controls.
  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = SaloneColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme _buildTextTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primaryText,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onPrimary,
        letterSpacing: 0.1,
      ),
    );
  }

  // ── Light theme (Primary) ─────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: SaloneColors.primary,
          onPrimary: Colors.white,
          secondary: SaloneColors.secondary,
          onSecondary: Colors.white,
          tertiary: SaloneColors.gold,
          onTertiary: SaloneColors.textPrimary,
          surface: SaloneColors.surface,
          onSurface: SaloneColors.textPrimary,
          error: SaloneColors.error,
          onError: Colors.white,
          outline: SaloneColors.border,
          surfaceContainerHighest: SaloneColors.surfaceContainer,
        ),
        scaffoldBackgroundColor: SaloneColors.background,
        textTheme: _buildTextTheme(
          SaloneColors.textPrimary,
          SaloneColors.textSecondary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: SaloneColors.surface,
          foregroundColor: SaloneColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SaloneColors.textPrimary,
            letterSpacing: -0.2,
          ),
          iconTheme: const IconThemeData(color: SaloneColors.textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SaloneColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: SaloneColors.border,
            disabledForegroundColor: SaloneColors.textSecondary,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SaloneColors.primary,
            side: const BorderSide(color: SaloneColors.border, width: 1.25),
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: SaloneColors.secondary,
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SaloneColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: SaloneColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: SaloneColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: SaloneColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: SaloneColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: SaloneColors.error, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: SaloneColors.textSecondary,
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SaloneColors.textSecondary,
          ),
        ),
        cardTheme: CardThemeData(
          color: SaloneColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
            side: const BorderSide(color: SaloneColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: SaloneColors.surface,
          selectedColor: SaloneColors.primary,
          side: const BorderSide(color: SaloneColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: SaloneColors.textPrimary,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: SaloneColors.surface,
          selectedItemColor: SaloneColors.primary,
          unselectedItemColor: SaloneColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: SaloneColors.border,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: SaloneColors.primary,
          contentTextStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: SaloneColors.secondary,
          onPrimary: Colors.white,
          secondary: SaloneColors.gold,
          onSecondary: SaloneColors.textPrimary,
          surface: SaloneColors.darkSurface,
          onSurface: SaloneColors.darkTextPrimary,
          error: SaloneColors.error,
          onError: Colors.white,
          outline: SaloneColors.darkBorder,
          surfaceContainerHighest: SaloneColors.darkSurfaceContainer,
        ),
        scaffoldBackgroundColor: SaloneColors.darkBackground,
        textTheme: _buildTextTheme(
          SaloneColors.darkTextPrimary,
          SaloneColors.darkTextSecondary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: SaloneColors.darkSurface,
          foregroundColor: SaloneColors.darkTextPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SaloneColors.darkTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: SaloneColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
            side: const BorderSide(color: SaloneColors.darkBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
      );
}
