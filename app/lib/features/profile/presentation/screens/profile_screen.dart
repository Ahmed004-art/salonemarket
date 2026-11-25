import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_notifier.dart';
import '../../../notifications/presentation/controllers/notifications_notifier.dart';

/// Customer profile screen with account info, quick action tiles, role-based portal links.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final profile = auth.profile;
    final isVendor = auth.isVendor;
    final isAdmin = auth.isAdmin;
    final unreadNotifications =
        context.watch<NotificationsNotifier>().unreadCount;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'My Account',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // User Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: SaloneMarketTheme.border),
              ),
              color: SaloneMarketTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: SaloneMarketTheme.primary.withOpacity(0.1),
                      backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(profile.avatarUrl!)
                          : null,
                      child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                          ? Text(
                              auth.userDisplayName.isNotEmpty
                                  ? auth.userDisplayName[0].toUpperCase()
                                  : 'U',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: SaloneMarketTheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userDisplayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? Colors.purple.shade50
                                  : (isVendor
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profile?.role.toUpperCase() ?? 'CUSTOMER',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAdmin
                                    ? Colors.purple.shade800
                                    : (isVendor
                                        ? Colors.orange.shade800
                                        : Colors.blue.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Profile',
                      onPressed: () => context.push(Routes.profileEdit),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Navigation Section 1: Customer Actions
            _buildSectionHeader('Shopping & Activity'),
            _buildActionTile(
              context: context,
              icon: Icons.receipt_long_outlined,
              title: 'Order History',
              subtitle: 'Track past and active purchases',
              onTap: () => context.push(Routes.orders),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.favorite_border,
              title: 'Saved Items / Wishlist',
              subtitle: 'View saved favorite products',
              onTap: () => context.push(Routes.wishlist),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.notifications_none,
              title: 'Notifications',
              subtitle: 'Order updates and system alerts',
              badge: unreadNotifications > 0 ? '$unreadNotifications' : null,
              onTap: () => context.push(Routes.notifications),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.location_on_outlined,
              title: 'Delivery Addresses',
              subtitle: 'Manage saved delivery destinations',
              onTap: () => context.push(Routes.addresses),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Navigation Section 2: Portals
            _buildSectionHeader('Merchant & Management'),
            if (isVendor) ...[
              _buildActionTile(
                context: context,
                icon: Icons.storefront_outlined,
                title: 'Vendor Portal',
                subtitle: 'Manage catalog, orders & store payouts',
                onTap: () => context.push(Routes.vendorDashboard),
              ),
            ] else ...[
              _buildActionTile(
                context: context,
                icon: Icons.storefront_outlined,
                title: 'Become a SaloneMarket Vendor',
                subtitle: 'Apply to sell products in Sierra Leone',
                onTap: () => context.push(Routes.vendorApplication),
              ),
            ],
            if (isAdmin) ...[
              _buildActionTile(
                context: context,
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Dashboard',
                subtitle: 'Oversee vendors, products & transactions',
                onTap: () => context.push(Routes.adminDashboard),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Navigation Section 3: App & Support
            _buildSectionHeader('Preferences & Support'),
            _buildActionTile(
              context: context,
              icon: Icons.feedback_outlined,
              title: 'Customer Feedback & Dispute Support',
              subtitle: 'Submit inquiries, feedback, or refund requests',
              onTap: () => context.push('/profile/feedback'),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Currency, language, terms & security',
              onTap: () => context.push(Routes.settings),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.signOut();
                  if (context.mounted) {
                    context.go(Routes.login);
                  }
                },
                icon: const Icon(Icons.logout, color: SaloneMarketTheme.error),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.dmSans(
                    color: SaloneMarketTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: SaloneMarketTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: SaloneMarketTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: SaloneMarketTheme.border),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: SaloneMarketTheme.cream,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Icon(icon, color: SaloneMarketTheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: SaloneMarketTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: SaloneMarketTheme.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SaloneMarketTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
