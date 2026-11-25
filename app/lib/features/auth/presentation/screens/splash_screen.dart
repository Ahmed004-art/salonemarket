import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_logo.dart';
import '../../../../core/widgets/salone_motion.dart';
import '../controllers/auth_notifier.dart';

const String kOnboardingCompletedKey = 'salone_onboarding_completed';

/// Branded splash screen with animated logo reveal and onboarding/session routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _routeAfterIntro();
  }

  Future<void> _routeAfterIntro() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final auth = context.read<AuthNotifier>();
    if (auth.isAuthenticated) {
      context.go(Routes.home);
      return;
    }

    bool onboardingDone = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool(kOnboardingCompletedKey) ?? false;
    } catch (_) {
      onboardingDone = false;
    }

    if (!mounted) return;
    if (onboardingDone) {
      context.go(Routes.welcome);
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SaloneMotion.reduceMotion(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SaloneLogo(
          variant: SaloneLogoVariant.iconOnly,
          tone: SaloneLogoTone.darkBackground,
          markSize: 84,
        ),
        const SizedBox(height: AppSpacing.lg),
        RichText(
          text: TextSpan(
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: const [
              TextSpan(text: 'Salone', style: TextStyle(color: Colors.white)),
              TextSpan(
                text: 'Market',
                style: TextStyle(color: SaloneColors.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sierra Leone Mobile Commerce',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SaloneColors.cream.withValues(alpha: 0.8),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: SaloneColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: reduce
                  ? content
                  : FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(scale: _scale, child: content),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xxl,
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SaloneColors.gold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
