import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/core/utils/validators.dart';

void main() {
  group('Validators - validateFullName', () {
    test('returns error for empty or null name', () {
      expect(Validators.validateFullName(null), 'Please enter your full name');
      expect(Validators.validateFullName(''), 'Please enter your full name');
      expect(Validators.validateFullName('   '), 'Please enter your full name');
    });

    test('returns error for too short name', () {
      expect(Validators.validateFullName('A'), 'Name must be at least 2 characters long');
    });

    test('returns null for valid names', () {
      expect(Validators.validateFullName('Alie Kamara'), isNull);
      expect(Validators.validateFullName('Fatmata Sesay'), isNull);
      expect(Validators.validateFullName('Dr. John Conteh'), isNull);
    });
  });

  group('Validators - validateEmail', () {
    test('returns error for empty or null email', () {
      expect(Validators.validateEmail(null), 'Please enter your email address');
      expect(Validators.validateEmail(''), 'Please enter your email address');
      expect(Validators.validateEmail('  '), 'Please enter your email address');
    });

    test('returns error for invalid email formats', () {
      expect(Validators.validateEmail('alie'), 'Please enter a valid email address');
      expect(Validators.validateEmail('alie@'), 'Please enter a valid email address');
      expect(Validators.validateEmail('alie@gmail'), 'Please enter a valid email address');
      expect(Validators.validateEmail('alie@.com'), 'Please enter a valid email address');
      expect(Validators.validateEmail('alie kamara@gmail.com'), 'Please enter a valid email address');
    });

    test('returns null for valid email formats', () {
      expect(Validators.validateEmail('alie@salonemarket.sl'), isNull);
      expect(Validators.validateEmail('fatmata.sesay@gmail.com'), isNull);
      expect(Validators.validateEmail('vendor_123@yahoo.co.uk'), isNull);
    });
  });

  group('Validators - validatePassword', () {
    test('returns error for empty or null password', () {
      expect(Validators.validatePassword(null), 'Please enter a password');
      expect(Validators.validatePassword(''), 'Please enter a password');
    });

    test('returns error for passwords under 8 characters', () {
      expect(Validators.validatePassword('Pass1'), 'Password must be at least 8 characters long');
      expect(Validators.validatePassword('1234567'), 'Password must be at least 8 characters long');
    });

    test('returns error for passwords without numbers or without letters', () {
      expect(Validators.validatePassword('alllettersonly'), 'Password must include both letters and numbers');
      expect(Validators.validatePassword('1234567890'), 'Password must include both letters and numbers');
    });

    test('returns null for valid passwords', () {
      expect(Validators.validatePassword('SaloneMarket2026'), isNull);
      expect(Validators.validatePassword('freetown99'), isNull);
      expect(Validators.validatePassword('Secure#P4ssword'), isNull);
    });
  });

  group('Validators - validateConfirmPassword', () {
    test('returns error for empty confirm password', () {
      expect(Validators.validateConfirmPassword(null, 'Pass1234'), 'Please confirm your password');
      expect(Validators.validateConfirmPassword('', 'Pass1234'), 'Please confirm your password');
    });

    test('returns error when passwords do not match', () {
      expect(Validators.validateConfirmPassword('Different123', 'Pass1234'), 'Passwords do not match');
    });

    test('returns null when passwords match', () {
      expect(Validators.validateConfirmPassword('Pass1234', 'Pass1234'), isNull);
    });
  });

  group('Validators - validatePhone', () {
    test('returns null for empty phone when not required', () {
      expect(Validators.validatePhone(null), isNull);
      expect(Validators.validatePhone(''), isNull);
      expect(Validators.validatePhone('  '), isNull);
    });

    test('returns error for empty phone when required', () {
      expect(Validators.validatePhone(null, required: true), 'Please enter a phone number');
      expect(Validators.validatePhone('', required: true), 'Please enter a phone number');
    });

    test('validates Sierra Leone phone numbers', () {
      // Valid local formats (Orange, Africell, QCell: 76, 77, 78, 79, 88, 30, 31, 33, 99)
      expect(Validators.validatePhone('076123456'), isNull);
      expect(Validators.validatePhone('+232 76 123456'), isNull);
      expect(Validators.validatePhone('232 88 654321'), isNull);
      expect(Validators.validatePhone('030 112233'), isNull);
      expect(Validators.validatePhone('077-123-456'), isNull);

      // Invalid
      expect(Validators.validatePhone('12345'), isNotNull);
      expect(Validators.validatePhone('012345678'), isNotNull);
    });
  });
}
