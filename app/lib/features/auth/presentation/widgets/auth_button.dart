import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

enum AuthButtonVariant {
  primary,   // Warm Amber fill, Navy text
  secondary, // Navy outline, Navy text
}

/// Primary and secondary action buttons conforming to SaloneMarket design language.
///
/// Features:
/// - 52px standard touch target height
/// - 8px border radius
/// - Integrated loading spinner state
/// - Disabled visual styling
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AuthButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final AuthButtonVariant variant;
  final bool isLoading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    if (variant == AuthButtonVariant.primary) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: SaloneMarketTheme.accent,
            foregroundColor: SaloneMarketTheme.onAccent,
            disabledBackgroundColor: SaloneMarketTheme.accent.withValues(alpha: 0.5),
            disabledForegroundColor: SaloneMarketTheme.onAccent.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      SaloneMarketTheme.onAccent,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SaloneMarketTheme.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    // Secondary variant (navy outline)
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: SaloneMarketTheme.primary,
          side: BorderSide(
            color: isEnabled
                ? SaloneMarketTheme.primary
                : SaloneMarketTheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SaloneMarketTheme.primary,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
