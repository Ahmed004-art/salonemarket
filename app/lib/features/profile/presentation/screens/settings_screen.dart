import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Application settings, preferences, currency display, legal information.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildCard(
            title: 'Regional & Currency',
            children: [
              _buildListTile(
                icon: Icons.currency_exchange,
                title: 'Currency',
                subtitle: 'Sierra Leonean Leone (SLE)',
                onTap: null,
              ),
              const Divider(height: 1, color: SaloneMarketTheme.border),
              _buildListTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English (Sierra Leone)',
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          _buildCard(
            title: 'Support & Feedback',
            children: [
              _buildListTile(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback or Dispute',
                subtitle: 'Report delivery issues or contact support',
                onTap: () => context.push('/profile/feedback'),
              ),
              const Divider(height: 1, color: SaloneMarketTheme.border),
              _buildListTile(
                icon: Icons.help_outline,
                title: 'Help Center & FAQ',
                subtitle: 'Guides on orders, Monime payments & deliveries',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('SaloneMarket Help'),
                      content: const Text(
                        'For order support or live payment queries, '
                        'contact support@salonemarket.sl or visit our Freetown help desk.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          _buildCard(
            title: 'Legal & Compliance',
            children: [
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Marketplace buyer and merchant terms',
                onTap: () {},
              ),
              const Divider(height: 1, color: SaloneMarketTheme.border),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How your customer data is stored securely',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: Text(
              'SaloneMarket App v1.0.0 (SLE Ready)',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SaloneMarketTheme.textSecondary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SaloneMarketTheme.border),
          ),
          color: SaloneMarketTheme.surface,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: SaloneMarketTheme.primary),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: SaloneMarketTheme.textSecondary,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: SaloneMarketTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }
}
