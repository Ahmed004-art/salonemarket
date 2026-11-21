import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/controllers/cart_notifier.dart';

/// Top app bar for marketplace screens featuring branding, delivery location, and cart badge.
class MarketplaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketplaceAppBar({
    super.key,
    this.showBack = false,
    this.title,
  });

  final bool showBack;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final cartNotifier = context.watch<CartNotifier>();
    final itemCount = cartNotifier.itemCount;

    return AppBar(
      backgroundColor: SaloneMarketTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: SaloneMarketTheme.primary,
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.home);
                }
              },
            )
          : Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SaloneMarketTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SaloneMarketTheme.accent.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'SM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SaloneMarketTheme.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      title: title != null
          ? Text(
              title!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SaloneMarketTheme.primary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SALONEMARKET',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: SaloneMarketTheme.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: SaloneMarketTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SL',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: SaloneMarketTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: SaloneMarketTheme.muted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Freetown & Nationwide',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: SaloneMarketTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, size: 22),
          color: SaloneMarketTheme.primary,
          tooltip: 'Search catalog',
          onPressed: () => context.push(Routes.search),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, size: 22),
              color: SaloneMarketTheme.primary,
              tooltip: 'Shopping Cart',
              onPressed: () => context.push(Routes.cart),
            ),
            if (itemCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: SaloneMarketTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      itemCount > 99 ? '99+' : '$itemCount',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SaloneMarketTheme.onAccent,
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
