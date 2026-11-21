import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/address/data/models/address_model.dart';
import 'package:salonemarket/features/address/data/repositories/address_repository.dart';

void main() {
  group('AddressRepository Base Behavior Tests', () {
    late AddressRepository repository;

    setUp(() {
      repository = AddressRepository();
    });

    test('isReady is false when Supabase is not configured', () {
      expect(repository.isReady, isFalse);
    });

    test('getAddresses fails gracefully when unconfigured', () async {
      final result = await repository.getAddresses();
      expect(result, isA<AddressFailure<List<Address>>>());
      expect(
        (result as AddressFailure<List<Address>>).message,
        contains('not configured'),
      );
    });

    test('addAddress fails gracefully when unconfigured', () async {
      const address = Address(
        id: 'addr-1',
        profileId: 'user-1',
        addressLine1: 'Wilkinson Road',
      );
      final result = await repository.addAddress(address);
      expect(result, isA<AddressFailure<Address>>());
      expect(
        (result as AddressFailure<Address>).message,
        contains('not configured'),
      );
    });

    test('deleteAddress fails gracefully when unconfigured', () async {
      final result = await repository.deleteAddress('addr-1');
      expect(result, isA<AddressFailure<void>>());
      expect(
        (result as AddressFailure<void>).message,
        contains('not configured'),
      );
    });

    test('setDefaultAddress fails gracefully when unconfigured', () async {
      final result = await repository.setDefaultAddress('addr-1');
      expect(result, isA<AddressFailure<void>>());
      expect(
        (result as AddressFailure<void>).message,
        contains('not configured'),
      );
    });
  });
}
