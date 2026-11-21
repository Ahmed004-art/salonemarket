import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../marketplace/presentation/widgets/empty_state_view.dart';
import '../../data/models/address_model.dart';
import '../controllers/address_notifier.dart';

/// Screen listing customer saved delivery addresses with CRUD actions.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({
    super.key,
    this.isSelectionMode = false,
  });

  final bool isSelectionMode;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressNotifier>().loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AddressNotifier>();
    final addresses = notifier.addresses;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode
              ? 'Select Delivery Address'
              : 'Delivery Addresses',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: notifier.isLoading && addresses.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: SaloneMarketTheme.primary),
            )
          : addresses.isEmpty
              ? EmptyStateView(
                  icon: Icons.location_on_outlined,
                  title: 'No addresses saved',
                  message:
                      'Add your delivery address in Freetown, Bo, Kenema, Makeni, or anywhere across Sierra Leone.',
                  actionLabel: 'Add New Address',
                  onAction: () => context.push(Routes.addressNew),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isSelected =
                        notifier.selectedAddress?.id == address.id;

                    return _AddressCard(
                      address: address,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: isSelected,
                      onSelect: () {
                        notifier.selectAddress(address);
                        if (widget.isSelectionMode) {
                          context.pop(address);
                        }
                      },
                      onEdit: () => context.push(
                        Routes.addressEdit.replaceFirst(
                          ':addressId',
                          address.id,
                        ),
                        extra: address,
                      ),
                      onDelete: () => _confirmDelete(context, address),
                      onSetDefault: () =>
                          notifier.setDefaultAddress(address.id),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SaloneMarketTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 20),
              label: Text(
                'Add New Address',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              onPressed: () => context.push(Routes.addressNew),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Address address) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Address?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${address.label} - ${address.addressLine1}"?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SaloneMarketTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context.read<AddressNotifier>().deleteAddress(address.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaloneMarketTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? SaloneMarketTheme.accent
              : SaloneMarketTheme.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Label Chip, Default Badge, and Selector/Menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: SaloneMarketTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      address.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: SaloneMarketTheme.primary,
                      ),
                    ),
                  ),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SaloneMarketTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Default',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: SaloneMarketTheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isSelectionMode)
                    Radio<bool>(
                      value: true,
                      groupValue: isSelected,
                      onChanged: (_) => onSelect(),
                      activeColor: SaloneMarketTheme.accent,
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: SaloneMarketTheme.muted,
                      ),
                      onSelected: (action) {
                        if (action == 'edit') {
                          onEdit();
                        } else if (action == 'default') {
                          onSetDefault();
                        } else if (action == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        if (!address.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Set as Default'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: SaloneMarketTheme.error),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Recipient & Phone
              if (address.fullName != null && address.fullName!.isNotEmpty)
                Text(
                  address.fullName!,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: SaloneMarketTheme.primary,
                  ),
                ),
              if (address.phone != null && address.phone!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address.phone!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: SaloneMarketTheme.muted,
                  ),
                ),
              ],
              const SizedBox(height: 6),

              // Full address line
              Text(
                address.formattedAddress,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: SaloneMarketTheme.primary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
