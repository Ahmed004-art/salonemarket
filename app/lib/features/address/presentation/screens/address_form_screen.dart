import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/address_model.dart';
import '../controllers/address_notifier.dart';

/// Form screen for adding a new address or editing an existing one.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({
    super.key,
    this.existingAddress,
  });

  final Address? existingAddress;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _line1Controller;
  late TextEditingController _line2Controller;

  late String _selectedLabel;
  late String _selectedCity;
  late String _selectedDistrict;
  late bool _isDefault;

  static const List<String> _labels = ['Home', 'Work', 'Shop', 'Other'];

  static const List<String> _cities = [
    'Freetown',
    'Bo',
    'Kenema',
    'Makeni',
    'Waterloo',
    'Koidu',
    'Port Loko',
    'Kabala',
    'Magburaka',
    'Lunsar',
  ];

  static const List<String> _districts = [
    'Western Area Urban',
    'Western Area Rural',
    'Bo',
    'Kenema',
    'Bombali',
    'Port Loko',
    'Kono',
    'Tonkolili',
    'Kambia',
    'Moyamba',
    'Bonthe',
    'Pujehun',
    'Kailahun',
    'Koinadugu',
    'Falaba',
    'Karene',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _nameController = TextEditingController(text: a?.fullName ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _line1Controller = TextEditingController(text: a?.addressLine1 ?? '');
    _line2Controller = TextEditingController(text: a?.addressLine2 ?? '');

    _selectedLabel = a?.label ?? 'Home';
    _selectedCity = (a != null && _cities.contains(a.city))
        ? a.city
        : 'Freetown';
    _selectedDistrict = (a != null && a.district != null && _districts.contains(a.district))
        ? a.district!
        : 'Western Area Urban';
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = context.read<AddressNotifier>();
    final isEditing = widget.existingAddress != null;

    final address = Address(
      id: widget.existingAddress?.id ?? '',
      profileId: widget.existingAddress?.profileId ?? '',
      label: _selectedLabel,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      addressLine1: _line1Controller.text.trim(),
      addressLine2: _line2Controller.text.trim().isEmpty
          ? null
          : _line2Controller.text.trim(),
      city: _selectedCity,
      district: _selectedDistrict,
      isDefault: _isDefault,
    );

    final success = isEditing
        ? await notifier.updateAddress(address)
        : await notifier.addAddress(address);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Address updated successfully' : 'Address saved',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: SaloneMarketTheme.primary,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notifier.errorMessage ?? 'Failed to save address',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: SaloneMarketTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AddressNotifier>();
    final isEditing = widget.existingAddress != null;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.surface,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Address' : 'Add Delivery Address',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address Type / Label
              Text(
                'Address Label',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: SaloneMarketTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _labels.map((label) {
                  final isSelected = _selectedLabel == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: SaloneMarketTheme.primary,
                    labelStyle: GoogleFonts.dmSans(
                      color: isSelected
                          ? Colors.white
                          : SaloneMarketTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedLabel = label);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Full Name *',
                  hintText: 'e.g. Amadu Kamara',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.validateFullName,
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Sierra Leone) *',
                  hintText: '076 123456 or +232 76 123456',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (val) =>
                    Validators.validatePhone(val, required: true),
              ),
              const SizedBox(height: 16),

              // City and District Dropdowns in a Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'City / Town *',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: _cities
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: GoogleFonts.dmSans(fontSize: 14)),
                              ),)
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCity = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: 'District *',
                      ),
                      items: _districts
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d, style: GoogleFonts.dmSans(fontSize: 14)),
                              ),)
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDistrict = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Address Line 1
              TextFormField(
                controller: _line1Controller,
                decoration: const InputDecoration(
                  labelText: 'Street Address or Community *',
                  hintText: 'e.g. 24 Campbell Street, near Wilberforce Junction',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter street address or landmark';
                  }
                  if (val.trim().length < 3) {
                    return 'Address must be at least 3 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address Line 2
              TextFormField(
                controller: _line2Controller,
                decoration: const InputDecoration(
                  labelText: 'Apartment, Suite, Landmark (Optional)',
                  hintText: 'e.g. 2nd Floor, Green Gate, opposite Mosque',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Set as default checkbox switch
              SwitchListTile(
                title: Text(
                  'Set as default delivery address',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'This address will be automatically selected during checkout.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
                value: _isDefault,
                activeColor: SaloneMarketTheme.accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isDefault = val),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaloneMarketTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: notifier.isLoading ? null : _handleSave,
                  child: notifier.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Address' : 'Save Address',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
