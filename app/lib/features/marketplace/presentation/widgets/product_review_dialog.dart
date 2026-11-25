import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Modal dialog for customer product rating and review submission,
/// enforcing server-side verified purchase checks.
class ProductReviewDialog extends StatefulWidget {
  const ProductReviewDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  State<ProductReviewDialog> createState() => _ProductReviewDialogState();
}

class _ProductReviewDialogState extends State<ProductReviewDialog> {
  bool _isChecking = true;
  bool _isEligible = false;
  String? _ineligibleReason;
  bool _isSubmitting = false;

  int _rating = 5;
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    if (!AppConstants.isSupabaseConfigured) {
      setState(() {
        _isChecking = false;
        _isEligible = true; // In offline mock mode, allow testing dialog UI
      });
      return;
    }

    try {
      final res = await Supabase.instance.client.rpc(
        'check_review_eligibility',
        params: {'p_product_id': widget.productId},
      );

      final data = res as Map<String, dynamic>;
      final eligible = data['eligible'] == true;

      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _isEligible = eligible;
        _ineligibleReason = data['reason']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _isEligible = false;
        _ineligibleReason = 'Could not verify purchase eligibility.';
      });
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      if (AppConstants.isSupabaseConfigured) {
        await Supabase.instance.client.rpc(
          'submit_product_review',
          params: {
            'p_product_id': widget.productId,
            'p_rating': _rating,
            'p_title': _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
            'p_comment': _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
          },
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your verified review has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e'),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Review: ${widget.productName}',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: _isChecking
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : !_isEligible
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 48,
                      color: SaloneMarketTheme.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _ineligibleReason ??
                          'Only customers with a verified, paid order can review this product.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: SaloneMarketTheme.textSecondary,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Rating',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            icon: Icon(
                              star <= _rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () => setState(() => _rating = star),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Review Title (Optional)',
                          hintText: 'e.g., Excellent quality fresh fish!',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comments',
                          hintText: 'Share your experience with other buyers...',
                        ),
                      ),
                    ],
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_isEligible)
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: SaloneMarketTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Review'),
          ),
      ],
    );
  }
}
