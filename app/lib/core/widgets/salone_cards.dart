import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'salone_buttons.dart';
import 'salone_motion.dart';

/// Consistent elevated surface container across customer, vendor, and admin views.
class SaloneCard extends StatelessWidget {
  const SaloneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.onTap,
    this.radius = AppRadius.large,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? SaloneColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? SaloneColors.border),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Consistent section header with optional right-aligned action.
class SaloneSectionHeader extends StatelessWidget {
  const SaloneSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SaloneColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: SaloneColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            SaloneGhostButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.arrow_forward_ios_rounded,
            ),
        ],
      ),
    );
  }
}

/// Reusable KPI / Metric card for Vendor and Admin dashboards.
class SaloneMetricCard extends StatelessWidget {
  const SaloneMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor = SaloneColors.secondary,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SaloneFadeIn(
      child: SaloneCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: SaloneColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: SaloneColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SaloneColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

enum SaloneBadgeTone { neutral, success, warning, error, info, primary }

/// Clean semantic status pill used across orders, vendors, products, and payouts.
class SaloneStatusBadge extends StatelessWidget {
  const SaloneStatusBadge({
    super.key,
    required this.label,
    this.tone = SaloneBadgeTone.neutral,
  });

  final String label;
  final SaloneBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      SaloneBadgeTone.success => (
          SaloneColors.success.withValues(alpha: 0.12),
          SaloneColors.success,
        ),
      SaloneBadgeTone.warning => (
          SaloneColors.gold.withValues(alpha: 0.2),
          const Color(0xFF8A5A10),
        ),
      SaloneBadgeTone.error => (
          SaloneColors.error.withValues(alpha: 0.12),
          SaloneColors.error,
        ),
      SaloneBadgeTone.info => (
          SaloneColors.info.withValues(alpha: 0.12),
          SaloneColors.info,
        ),
      SaloneBadgeTone.primary => (
          SaloneColors.primary.withValues(alpha: 0.1),
          SaloneColors.primary,
        ),
      SaloneBadgeTone.neutral => (
          SaloneColors.surfaceContainer,
          SaloneColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
