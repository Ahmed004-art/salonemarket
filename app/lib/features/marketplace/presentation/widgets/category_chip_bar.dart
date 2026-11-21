import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/category_model.dart';

/// Horizontal category filter pills used across Home and Catalog screens.
class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length + 1, // +1 for "All Categories"
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedCategoryId == null;
            return _buildChip(
              title: 'All Items',
              isSelected: isSelected,
              onTap: () => onCategorySelected(null),
            );
          }

          final category = categories[index - 1];
          final isSelected = selectedCategoryId == category.id;
          return _buildChip(
            title: category.name,
            isSelected: isSelected,
            onTap: () => onCategorySelected(category.id),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? SaloneMarketTheme.primary
              : SaloneMarketTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? SaloneMarketTheme.primary
                : SaloneMarketTheme.border,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? SaloneMarketTheme.onPrimary
                  : SaloneMarketTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
