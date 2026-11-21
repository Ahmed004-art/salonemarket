import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Stepper widget for selecting product purchase quantity.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.maxQuantity = 99,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SaloneMarketTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            color: quantity > 1
                ? SaloneMarketTheme.primary
                : SaloneMarketTheme.muted,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SaloneMarketTheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: quantity < maxQuantity
                ? SaloneMarketTheme.primary
                : SaloneMarketTheme.muted,
            onPressed:
                quantity < maxQuantity ? () => onChanged(quantity + 1) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
