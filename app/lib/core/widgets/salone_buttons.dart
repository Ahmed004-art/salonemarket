import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'salone_motion.dart';

/// Primary brand action button with press-scale microinteraction and loading state.
class SalonePrimaryButton extends StatefulWidget {
  const SalonePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  @override
  State<SalonePrimaryButton> createState() => _SalonePrimaryButtonState();
}

class _SalonePrimaryButtonState extends State<SalonePrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final reduce = SaloneMotion.reduceMotion(context);
    final bg = widget.backgroundColor ?? SaloneColors.primary;
    final fg = widget.foregroundColor ?? Colors.white;

    final button = ElevatedButton(
      onPressed: disabled ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: SaloneColors.border,
        disabledForegroundColor: SaloneColors.textSecondary,
        minimumSize: Size(widget.fullWidth ? double.infinity : 0, widget.height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        elevation: 0,
      ),
      child: AnimatedSwitcher(
        duration: SaloneMotion.fast,
        child: widget.isLoading
            ? SizedBox(
                key: const ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return GestureDetector(
      onTapDown: disabled || reduce ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled || reduce ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled || reduce ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: SaloneMotion.fast,
        curve: SaloneMotion.easeOut,
        child: widget.fullWidth
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

/// Secondary outlined brand button.
class SaloneSecondaryButton extends StatelessWidget {
  const SaloneSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.borderColor,
    this.foregroundColor,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final Color? borderColor;
  final Color? foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? SaloneColors.primary;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: borderColor ?? SaloneColors.border, width: 1.25),
        minimumSize: Size(fullWidth ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Compact pill/ghost button for inline actions.
class SaloneGhostButton extends StatelessWidget {
  const SaloneGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? SaloneColors.secondary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
