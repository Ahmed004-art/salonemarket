import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SaloneMarket design system theme.
///
/// Usage: `theme: SaloneMarketTheme.lightTheme` in [MaterialApp].
class SaloneMarketTheme {
  SaloneMarketTheme._();

  // ── Colour palette ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1A1A2E); // Deep Navy
  static const Color accent = Color(0xFFE8A020); // Warm Amber
  static const Color background = Color(0xFFF7F4EF); // Warm Off-White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF9E9A94);
  static const Color success = Color(0xFF2D7A5F);
  static const Color error = Color(0xFFC0392B);
  static const Color vendorAccent = Color(0xFF2C5F8A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFF1A1A2E);
  static const Color onBackground = Color(0xFF1A1A2E);
  static const Color border = Color(0xFFE5E0D8);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: primary,
          onPrimary: onPrimary,
          secondary: accent,
          onSecondary: onAccent,
          surface: surface,
          onSurface: onBackground,
          error: error,
          onError: onPrimary,
          // ignore: deprecated_member_use
          background: background,
          // ignore: deprecated_member_use
          onBackground: onBackground,
          outline: border,
        ),
        scaffoldBackgroundColor: background,

        // ── AppBar ────────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: primary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          iconTheme: const IconThemeData(color: primary),
        ),

        // ── Text theme ────────────────────────────────────────────────────
        textTheme: TextTheme(
          displayLarge: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
          displayMedium: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
          headlineLarge: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          titleMedium: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primary,
          ),
          bodyLarge: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: primary,
          ),
          bodyMedium: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: primary,
          ),
          bodySmall: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: muted,
          ),
          labelLarge: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onPrimary,
          ),
        ),

        // ── Elevated button ───────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            elevation: 0,
          ),
        ),

        // ── Outlined button ───────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Input decoration ──────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: error, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: muted),
        ),

        // ── Card ──────────────────────────────────────────────────────────
        cardTheme: CardTheme(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),

        // ── Bottom navigation bar ─────────────────────────────────────────
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: accent,
          unselectedItemColor: muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 11),
        ),

        // ── Divider ───────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
          space: 1,
        ),
      );
}
