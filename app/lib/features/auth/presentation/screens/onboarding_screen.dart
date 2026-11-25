import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_buttons.dart';
import '../../../../core/widgets/salone_logo.dart';
import '../../../../core/widgets/salone_motion.dart';
import 'splash_screen.dart';

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.accentColor,
    required this.icon,
    required this.highlights,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final Color accentColor;
  final IconData icon;
  final List<String> highlights;
}

/// First-launch 3-step animated onboarding experience for SaloneMarket.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0.0;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      eyebrow: '01 • DISCOVER',
      headline: 'Discover products around you.',
      description:
          'Browse curated groceries, fashion, electronics, and home essentials from verified merchants in Freetown, Bo, Kenema, and Makeni.',
      accentColor: SaloneColors.secondary,
      icon: Icons.explore_outlined,
      highlights: ['Freetown', 'Bo', 'Kenema', 'Makeni'],
    ),
    _OnboardingSlideData(
      eyebrow: '02 • SHOP WITH CONFIDENCE',
      headline: 'Shopping made simple.',
      description:
          'Add items from multiple local stores to one cart, pay securely with Monime mobile money, and track every delivery step in real time.',
      accentColor: SaloneColors.gold,
      icon: Icons.verified_user_outlined,
      highlights: ['Monime Checkout', 'Live Tracking', 'Digital Receipts'],
    ),
    _OnboardingSlideData(
      eyebrow: '03 • GROW WITH SALONEMARKET',
      headline: 'A marketplace for everyone.',
      description:
          'Whether you are shopping for daily needs or running a Sierra Leonean business, SaloneMarket connects communities through trusted trade.',
      accentColor: SaloneColors.primary,
      icon: Icons.storefront_outlined,
      highlights: ['Verified Vendors', 'Fair Pricing', 'Fast Payouts'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _pageOffset = _pageController.page ?? _currentPage.toDouble();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingCompletedKey, true);
    } catch (_) {
      // Ignore storage errors and proceed cleanly
    }
    if (mounted) {
      context.go(route);
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: SaloneMotion.medium,
        curve: SaloneMotion.easeOut,
      );
    } else {
      _completeAndGo(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SaloneMotion.reduceMotion(context);
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: SaloneColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: compact logo + Skip
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SaloneLogo(
                    variant: SaloneLogoVariant.compact,
                    markSize: 32,
                  ),
                  if (!isLast)
                    SaloneGhostButton(
                      label: 'Skip',
                      onPressed: () => _completeAndGo(Routes.welcome),
                      color: SaloneColors.textSecondary,
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // Horizontal PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final delta = reduce ? 0.0 : (_pageOffset - index);
                  return _OnboardingSlideView(
                    slide: slide,
                    parallaxDelta: delta,
                    reduceMotion: reduce,
                  );
                },
              ),
            ),

            // Bottom controls: Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pagination dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: SaloneMotion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? SaloneColors.primary
                              : SaloneColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (!isLast)
                    SalonePrimaryButton(
                      label: 'Next',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                    )
                  else ...[
                    SalonePrimaryButton(
                      label: 'Get Started',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: () => _completeAndGo(Routes.home),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SaloneSecondaryButton(
                            label: 'Sign In',
                            onPressed: () => _completeAndGo(Routes.login),
                            height: 46,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SaloneSecondaryButton(
                            label: 'Create Account',
                            onPressed: () => _completeAndGo(Routes.register),
                            height: 46,
                            borderColor: SaloneColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.slide,
    required this.parallaxDelta,
    required this.reduceMotion,
  });

  final _OnboardingSlideData slide;
  final double parallaxDelta;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Custom vector-style brand composition with subtle parallax
          Transform.translate(
            offset: Offset(parallaxDelta * 26, 0),
            child: Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                color: SaloneColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: SaloneColors.border),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: slide.accentColor.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -18,
                    bottom: -18,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SaloneColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(parallaxDelta * 14, 0),
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: SaloneColors.primary,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppShadows.elevated,
                            ),
                            child: Icon(
                              slide.icon,
                              size: 40,
                              color: SaloneColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: slide.highlights.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: SaloneColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: SaloneColors.border),
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: SaloneColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Text block with smooth entrance
          Transform.translate(
            offset: Offset(parallaxDelta * 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.eyebrow,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: SaloneColors.secondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  slide.headline,
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: SaloneColors.textPrimary,
                    height: 1.18,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  slide.description,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: SaloneColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
