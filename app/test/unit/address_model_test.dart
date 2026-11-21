import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/address/data/models/address_model.dart';

void main() {
  group('Address Model Tests', () {
    test('fromMap parses valid database payload', () {
      final map = {
        'id': 'addr-1',
        'profile_id': 'user-1',
        'label': 'Home',
        'full_name': 'Fatmata Sesay',
        'phone': '076 123456',
        'address_line_1': '15 Wilkinson Road',
        'address_line_2': 'Near Lumley Roundabout',
        'city': 'Freetown',
        'district': 'Western Area Urban',
        'is_default': true,
        'created_at': '2026-11-20T10:00:00Z',
        'updated_at': '2026-11-20T10:00:00Z',
      };

      final address = Address.fromMap(map);

      expect(address.id, equals('addr-1'));
      expect(address.profileId, equals('user-1'));
      expect(address.label, equals('Home'));
      expect(address.fullName, equals('Fatmata Sesay'));
      expect(address.phone, equals('076 123456'));
      expect(address.addressLine1, equals('15 Wilkinson Road'));
      expect(address.addressLine2, equals('Near Lumley Roundabout'));
      expect(address.city, equals('Freetown'));
      expect(address.district, equals('Western Area Urban'));
      expect(address.isDefault, isTrue);
      expect(
        address.formattedAddress,
        equals('15 Wilkinson Road, Near Lumley Roundabout, Freetown, Western Area Urban'),
      );
    });

    test('fromMap safely handles null and fallback fields', () {
      final map = {
        'id': 'addr-2',
        'profile_id': 'user-1',
        'address_line_1': 'Bo Commercial Road',
      };

      final address = Address.fromMap(map);

      expect(address.id, equals('addr-2'));
      expect(address.label, equals('Home'));
      expect(address.fullName, isNull);
      expect(address.recipientName, equals('Recipient'));
      expect(address.city, equals('Freetown'));
      expect(address.isDefault, isFalse);
      expect(address.formattedAddress, equals('Bo Commercial Road, Freetown'));
    });

    test('toMap serializes attributes correctly', () {
      const address = Address(
        id: 'addr-3',
        profileId: 'user-2',
        label: 'Work',
        fullName: 'Mohamed Bangura',
        phone: '078 987654',
        addressLine1: '32 Siaka Stevens Street',
        district: 'Western Area Urban',
      );

      final map = address.toMap();

      expect(map['id'], equals('addr-3'));
      expect(map['profile_id'], equals('user-2'));
      expect(map['label'], equals('Work'));
      expect(map['full_name'], equals('Mohamed Bangura'));
      expect(map['phone'], equals('078 987654'));
      expect(map['address_line_1'], equals('32 Siaka Stevens Street'));
      expect(map['city'], equals('Freetown'));
      expect(map['is_default'], isFalse);
    });

    test('copyWith updates specified attributes', () {
      const address = Address(
        id: 'addr-1',
        profileId: 'user-1',
        addressLine1: 'Old Street',
      );

      final updated = address.copyWith(
        addressLine1: 'New Street',
        isDefault: true,
      );

      expect(updated.id, equals('addr-1'));
      expect(updated.addressLine1, equals('New Street'));
      expect(updated.isDefault, isTrue);
    });
  });
}
