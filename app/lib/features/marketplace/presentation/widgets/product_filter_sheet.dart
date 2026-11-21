import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Modal bottom sheet for sorting marketplace catalog items.
class ProductFilterSheet extends StatelessWidget {
  const ProductFilterSheet({
    super.key,
    required this.selectedSort,
    required this.onSortSelected,
  });

  final String selectedSort;
  final ValueChanged<String> onSortSelected;

  static const _sortOptions = [
    {'key': 'newest', 'label': 'Newest Arrivals'},
    {'key': 'popular', 'label': 'Most Popular'},
    {'key': 'rating', 'label': 'Highest Customer Rating'},
    {'key': 'price_asc', 'label': 'Price: Low to High'},
    {'key': 'price_desc', 'label': 'Price: High to Low'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SaloneMarketTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sort Products',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SaloneMarketTheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._sortOptions.map((opt) {
              final isSelected = selectedSort == opt['key'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  opt['label']!,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? SaloneMarketTheme.accent
                        : SaloneMarketTheme.primary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: SaloneMarketTheme.accent,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  onSortSelected(opt['key']!);
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
