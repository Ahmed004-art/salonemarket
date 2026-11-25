import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Central motion tokens & reduced-motion helpers for SaloneMarket.
class SaloneMotion {
  SaloneMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve easeOut = Curves.easeOutCubic;

  /// Returns `true` when the user/platform requests reduced motion.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Builds a smooth fade + subtle vertical slide page for GoRouter.
  static CustomTransitionPage<T> buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    if (reduceMotion(context)) {
      return NoTransitionPage<T>(key: state.pageKey, child: child);
    }
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: medium,
      reverseTransitionDuration: fast,
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: easeOut);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// Subtle, performance-friendly entrance animation for cards and sections.
class SaloneFadeIn extends StatelessWidget {
  const SaloneFadeIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 10,
  });

  final Widget child;
  final int delayMs;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    if (SaloneMotion.reduceMotion(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delayMs.clamp(0, 240)),
      curve: SaloneMotion.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
