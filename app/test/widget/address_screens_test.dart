import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/address/data/models/address_model.dart';
import 'package:salonemarket/features/address/data/repositories/address_repository.dart';
import 'package:salonemarket/features/address/presentation/controllers/address_notifier.dart';
import 'package:salonemarket/features/address/presentation/screens/address_form_screen.dart';
import 'package:salonemarket/features/address/presentation/screens/saved_addresses_screen.dart';

class MockAddressRepo implements AddressRepository {
  MockAddressRepo({List<Address>? initialAddresses})
      : addresses = initialAddresses ?? [];

  final List<Address> addresses;

  @override
  bool get isReady => true;

  @override
  String? get currentUserId => 'mock-user-123';

  @override
  Future<AddressResult<List<Address>>> getAddresses() async {
    return AddressSuccess(addresses);
  }

  @override
  Future<AddressResult<Address>> addAddress(Address address) async {
    addresses.add(address);
    return AddressSuccess(address);
  }

  @override
  Future<AddressResult<Address>> updateAddress(Address address) async {
    final idx = addresses.indexWhere((a) => a.id == address.id);
    if (idx != -1) addresses[idx] = address;
    return AddressSuccess(address);
  }

  @override
  Future<AddressResult<void>> deleteAddress(String addressId) async {
    addresses.removeWhere((a) => a.id == addressId);
    return const AddressSuccess(null);
  }

  @override
  Future<AddressResult<void>> setDefaultAddress(String addressId) async {
    return const AddressSuccess(null);
  }
}

Widget _wrapWithAddressProvider({
  required Widget child,
  AddressNotifier? addressNotifier,
}) {
  return ChangeNotifierProvider<AddressNotifier>.value(
    value: addressNotifier ??
        AddressNotifier(repository: MockAddressRepo()),
    child: MaterialApp(
      theme: SaloneMarketTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('SavedAddressesScreen Widget Tests', () {
    testWidgets('renders empty state when no saved addresses', (tester) async {
      final notifier = AddressNotifier(repository: MockAddressRepo(initialAddresses: []));

      await tester.pumpWidget(
        _wrapWithAddressProvider(
          child: const SavedAddressesScreen(),
          addressNotifier: notifier,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delivery Addresses'), findsOneWidget);
      expect(find.text('No addresses saved'), findsOneWidget);
      expect(find.text('Add New Address'), findsWidgets);
    });

    testWidgets('renders list of addresses with label, name and street', (tester) async {
      const addr = Address(
        id: 'addr-1',
        profileId: 'user-1',
        fullName: 'Hassan Koroma',
        phone: '076 543210',
        addressLine1: '12 Circular Road',
        district: 'Western Area Urban',
        isDefault: true,
      );

      final notifier = AddressNotifier(
        repository: MockAddressRepo(initialAddresses: [addr]),
      );

      await tester.pumpWidget(
        _wrapWithAddressProvider(
          child: const SavedAddressesScreen(),
          addressNotifier: notifier,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Hassan Koroma'), findsOneWidget);
      expect(find.text('076 543210'), findsOneWidget);
      expect(
        find.text('12 Circular Road, Freetown, Western Area Urban'),
        findsOneWidget,
      );
    });
  });

  group('AddressFormScreen Widget Tests', () {
    testWidgets('validates required fields on empty submit', (tester) async {
      await tester.pumpWidget(
        _wrapWithAddressProvider(child: const AddressFormScreen()),
      );
      await tester.pump();

      // Scroll and tap Save without entering data
      await tester.ensureVisible(find.text('Save Address'));
      await tester.tap(find.text('Save Address'));
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter a phone number'), findsOneWidget);
      expect(find.text('Please enter street address or landmark'), findsOneWidget);
    });

    testWidgets('pre-populates form when editing existing address', (tester) async {
      const existing = Address(
        id: 'addr-edit',
        profileId: 'user-1',
        label: 'Work',
        fullName: 'Zainab Turay',
        phone: '078 112233',
        addressLine1: '45 Pademba Road',
        district: 'Western Area Urban',
      );

      await tester.pumpWidget(
        _wrapWithAddressProvider(
          child: const AddressFormScreen(existingAddress: existing),
        ),
      );
      await tester.pump();

      expect(find.text('Edit Address'), findsOneWidget);
      expect(find.text('Zainab Turay'), findsOneWidget);
      expect(find.text('078 112233'), findsOneWidget);
      expect(find.text('45 Pademba Road'), findsOneWidget);
      expect(find.text('Update Address'), findsOneWidget);
    });
  });
}
