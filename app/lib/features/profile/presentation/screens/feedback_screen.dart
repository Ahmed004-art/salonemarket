import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen allowing customers to submit support inquiries, disputes, or feedback.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.initialOrderId,
  });

  final String? initialOrderId;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'general_feedback';
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  late final TextEditingController _orderIdController;
  bool _isSubmitting = false;

  final Map<String, String> _typeLabels = {
    'general_feedback': 'General Feedback / Suggestion',
    'product_issue': 'Product Quality or Defect Issue',
    'delivery_complaint': 'Delivery Delay or Complaint',
    'refund_request': 'Payment or Refund Request',
  };

  @override
  void initState() {
    super.initState();
    _orderIdController = TextEditingController(text: widget.initialOrderId ?? '');
    if (widget.initialOrderId != null) {
      _selectedType = 'delivery_complaint';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (AppConstants.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          final orderIdText = _orderIdController.text.trim();
          await client.from('customer_feedback').insert({
            'customer_id': userId,
            'customer_order_id': orderIdText.isNotEmpty ? orderIdText : null,
            'type': _selectedType,
            'subject': _subjectController.text.trim(),
            'message': _messageController.text.trim(),
          });
        }
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your feedback has been received. Our team will review it shortly.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $e'),
          backgroundColor: SaloneMarketTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Customer Support & Feedback',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How can we help you?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Let us know about your order experience, product satisfaction, or platform questions.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: SaloneMarketTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: SaloneMarketTheme.border),
                ),
                color: SaloneMarketTheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Feedback Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _typeLabels.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: GoogleFonts.dmSans(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _orderIdController,
                        decoration: const InputDecoration(
                          labelText: 'Order ID (Optional)',
                          hintText: 'e.g. UUID from your order receipt',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'Brief summary of the issue',
                          prefixIcon: Icon(Icons.subject),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Subject is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Message Details',
                          hintText: 'Describe what happened in detail...',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Message cannot be empty';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaloneMarketTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
