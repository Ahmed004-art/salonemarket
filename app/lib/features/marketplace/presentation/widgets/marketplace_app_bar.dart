import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_logo.dart';
import '../../../../core/widgets/salone_motion.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';

/// Top app bar for marketplace screens featuring SaloneMarket branding and cart badge.
class MarketplaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketplaceAppBar({
    super.key,
    this.showBack = false,
    this.title,
  });

  final bool showBack;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final cartNotifier = context.watch<CartNotifier>();
    final itemCount = cartNotifier.itemCount;

    return AppBar(
      backgroundColor: SaloneColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              color: SaloneColors.primary,
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.home);
                }
              },
            )
          : null,
      titleSpacing: showBack ? 0 : AppSpacing.lg,
      title: title != null
          ? Text(
              title!,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SaloneColors.textPrimary,
              ),
            )
          : const SaloneLogo(
              variant: SaloneLogoVariant.compact,
              markSize: 34,
              showTagline: true,
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          color: SaloneColors.primary,
          tooltip: 'Search catalog',
          onPressed: () => context.push(Routes.search),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, size: 22),
              color: SaloneColors.primary,
              tooltip: 'Shopping Cart',
              onPressed: () => context.push(Routes.cart),
            ),
            if (itemCount > 0)
              Positioned(
                top: 8,
                right: 7,
                child: AnimatedSwitcher(
                  duration: SaloneMotion.fast,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Container(
                    key: ValueKey<int>(itemCount),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SaloneColors.gold,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        itemCount > 99 ? '99+' : '$itemCount',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: SaloneColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
