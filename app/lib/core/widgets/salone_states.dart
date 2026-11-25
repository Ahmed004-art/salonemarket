import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'salone_buttons.dart';

/// Shimmer placeholder block for loading skeletons.
class SaloneShimmerBox extends StatelessWidget {
  const SaloneShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = AppRadius.medium,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: SaloneColors.surfaceContainer,
      highlightColor: SaloneColors.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: SaloneColors.surfaceContainer,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Product grid loading skeleton.
class SaloneProductGridSkeleton extends StatelessWidget {
  const SaloneProductGridSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.72,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const SaloneShimmerBox(
        height: 220,
        radius: AppRadius.large,
      ),
    );
  }
}

/// Vertical list loading skeleton for orders, vendors, and notifications.
class SaloneListSkeleton extends StatelessWidget {
  const SaloneListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const SaloneShimmerBox(
        height: 92,
        radius: AppRadius.large,
      ),
    );
  }
}

/// Polished empty state with subtle icon badge and optional action.
class SaloneEmptyState extends StatelessWidget {
  const SaloneEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: SaloneColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: SaloneColors.border),
                ),
                child: Icon(icon, size: 32, color: SaloneColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SaloneColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: SaloneColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SalonePrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  fullWidth: false,
                  height: 44,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Polished error state with actionable Retry button.
class SaloneErrorState extends StatelessWidget {
  const SaloneErrorState({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final firstLine = error.split('\n').first;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: SaloneColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: SaloneColors.error.withValues(alpha: 0.35),
            ),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SaloneColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: SaloneColors.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SaloneColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                firstLine,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: SaloneColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SalonePrimaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                fullWidth: false,
                height: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent floating toast/snackbar helper.
class SaloneToast {
  SaloneToast._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    final bg = isError
        ? SaloneColors.error
        : (isSuccess ? SaloneColors.success : SaloneColors.primary);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
