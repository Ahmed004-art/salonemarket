/// Input validation utilities for SaloneMarket forms.
///
/// All validators return `null` if valid, or a descriptive error message if invalid.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Validates full name: required, minimum 2 characters, reasonable length.
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    if (trimmed.length > 70) {
      return 'Name must be 70 characters or less';
    }
    return null;
  }

  /// Validates email address: required and properly formatted.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password: required, minimum 8 characters, at least 1 letter and 1 digit.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasDigit = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Password must include both letters and numbers';
    }
    return null;
  }

  /// Validates password confirmation matches original password.
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates phone number (optional or valid Sierra Leone / international format).
  static String? validatePhone(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Please enter a phone number' : null;
    }
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Supports: +232XX..., 0XX..., 232XX..., or 8-digit local number
    final phoneRegex = RegExp(r'^(?:\+?232|0)?[23789]\d{7}$');
    if (!phoneRegex.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g., 076 123456 or +232 76 123456)';
    }
    return null;
  }
}
