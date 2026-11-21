import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Standard text input field following the SaloneMarket design language.
///
/// Features:
/// - Static label positioned above the field (no floating label)
/// - 8px rounded corners with subtle 1px border
/// - Deep Navy focus state
/// - Error highlighting with descriptive message below
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.autocorrect = false,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final String hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool autocorrect;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above field
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: SaloneMarketTheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),

        // Text Form Field
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: enabled,
          autocorrect: autocorrect,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: SaloneMarketTheme.primary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.dmSans(
              fontSize: 14,
              color: SaloneMarketTheme.muted,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? SaloneMarketTheme.surface : const Color(0xFFF0ECE4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: SaloneMarketTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: SaloneMarketTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(
                color: SaloneMarketTheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: SaloneMarketTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(
                color: SaloneMarketTheme.error,
                width: 1.5,
              ),
            ),
            errorStyle: GoogleFonts.dmSans(
              fontSize: 12,
              color: SaloneMarketTheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
