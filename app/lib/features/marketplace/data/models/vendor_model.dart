double _parseDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _parseInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

/// Vendor model representing a merchant store on SaloneMarket.
class Vendor {
  const Vendor({
    required this.id,
    required this.profileId,
    required this.shopName,
    required this.slug,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.location,
    this.phone,
    this.email,
    this.status = 'pending',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.commissionRate = 0.05,
  });

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: (map['id']?.toString()) ?? '',
      profileId: (map['profile_id']?.toString()) ?? '',
      shopName: (map['shop_name']?.toString()) ?? 'Verified Seller',
      slug: (map['slug']?.toString()) ?? '',
      description: map['description']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      coverImageUrl: map['cover_image_url']?.toString(),
      location: (map['location']?.toString()) ?? 'Freetown, Sierra Leone',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      status: (map['status']?.toString()) ?? 'active',
      ratingAvg: _parseDouble(map['rating_avg']),
      ratingCount: _parseInt(map['rating_count']),
      commissionRate: _parseDouble(map['commission_rate'], 0.05),
    );
  }

  final String id;
  final String profileId;
  final String shopName;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? location;
  final String? phone;
  final String? email;
  final String status;
  final double ratingAvg;
  final int ratingCount;
  final double commissionRate;

  bool get isVerified => status == 'active';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': profileId,
      'shop_name': shopName,
      'slug': slug,
      'description': description,
      'logo_url': logoUrl,
      'cover_image_url': coverImageUrl,
      'location': location,
      'phone': phone,
      'email': email,
      'status': status,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'commission_rate': commissionRate,
    };
  }
}
