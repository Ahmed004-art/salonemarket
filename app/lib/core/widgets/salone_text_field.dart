import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Standardised form input field with Inter typography, clear focus state,
/// and optional password visibility toggle.
class SaloneTextField extends StatefulWidget {
  const SaloneTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final int maxLines;
  final bool enabled;

  @override
  State<SaloneTextField> createState() => _SaloneTextFieldState();
}

class _SaloneTextFieldState extends State<SaloneTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SaloneColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          enabled: widget.enabled,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: SaloneColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 19, color: SaloneColors.textSecondary)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 19,
                      color: SaloneColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Interactive or tap-to-search marketplace search bar.
class SaloneSearchBar extends StatelessWidget {
  const SaloneSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search Sierra Leone products & stores...',
    this.onTap,
    this.onSubmitted,
    this.onChanged,
    this.readOnly = false,
    this.trailing,
  });

  final TextEditingController? controller;
  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Material(
        color: SaloneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: SaloneColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: SaloneColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    hint,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: SaloneColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SaloneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(fontSize: 14, color: SaloneColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: SaloneColors.primary,
          ),
          suffixIcon: trailing,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
            borderSide: const BorderSide(color: SaloneColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
            borderSide: const BorderSide(color: SaloneColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
