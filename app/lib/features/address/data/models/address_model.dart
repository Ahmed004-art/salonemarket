/// Represents a customer delivery address on SaloneMarket.
///
/// Matches the schema of `public.addresses`.
class Address {
  const Address({
    required this.id,
    required this.profileId,
    required this.addressLine1,
    this.label = 'Home',
    this.fullName,
    this.phone,
    this.addressLine2,
    this.city = 'Freetown',
    this.district,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: (map['id']?.toString()) ?? '',
      profileId: (map['profile_id']?.toString()) ?? '',
      label: (map['label']?.toString()) ?? 'Home',
      fullName: map['full_name']?.toString(),
      phone: map['phone']?.toString(),
      addressLine1: (map['address_line_1']?.toString()) ?? '',
      addressLine2: map['address_line_2']?.toString(),
      city: (map['city']?.toString()) ?? 'Freetown',
      district: map['district']?.toString(),
      isDefault: map['is_default'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  final String id;
  final String profileId;
  final String label;
  final String? fullName;
  final String? phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? district;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Formatted single-line address description.
  String get formattedAddress {
    final buffer = StringBuffer(addressLine1);
    if (addressLine2 != null && addressLine2!.trim().isNotEmpty) {
      buffer.write(', ${addressLine2!.trim()}');
    }
    buffer.write(', $city');
    if (district != null && district!.trim().isNotEmpty) {
      buffer.write(', ${district!.trim()}');
    }
    return buffer.toString();
  }

  /// Recipient display header: `full_name` or fallback.
  String get recipientName => fullName?.trim().isNotEmpty == true
      ? fullName!.trim()
      : 'Recipient';

  Address copyWith({
    String? id,
    String? profileId,
    String? label,
    String? fullName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? district,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      district: district ?? this.district,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'profile_id': profileId,
      'label': label,
      'full_name': fullName,
      'phone': phone,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'district': district,
      'is_default': isDefault,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
