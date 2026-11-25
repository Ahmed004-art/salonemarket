import 'vendor_model.dart';

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

bool _parseBool(dynamic val, [bool fallback = true]) {
  if (val == null) return fallback;
  if (val is bool) return val;
  if (val is num) return val != 0;
  final str = val.toString().trim().toLowerCase();
  if (str == 'true' || str == '1') return true;
  if (str == 'false' || str == '0') return false;
  return fallback;
}

/// Single image asset associated with a product.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: (map['id']?.toString()) ?? '',
      productId: (map['product_id']?.toString()) ?? '',
      url: (map['url']?.toString()) ?? '',
      altText: map['alt_text']?.toString(),
      sortOrder: _parseInt(map['sort_order']),
      isPrimary: _parseBool(map['is_primary'], false),
    );
  }

  final String id;
  final String productId;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'url': url,
      'alt_text': altText,
      'sort_order': sortOrder,
      'is_primary': isPrimary,
    };
  }
}

/// Core Product model representing published inventory on SaloneMarket.
class Product {
  const Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.slug,
    required this.price,
    this.categoryId,
    this.categoryName,
    this.description,
    this.compareAtPrice,
    this.costPrice,
    this.sku,
    this.stockQuantity = 0,
    this.trackInventory = true,
    this.status = 'active',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.images = const [],
    this.vendor,
    this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    // Parse nested or joined images
    List<ProductImage> parsedImages = [];
    if (map['product_images'] != null && map['product_images'] is List) {
      parsedImages = (map['product_images'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductImage.fromMap)
          .toList();
      parsedImages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Parse joined vendor
    Vendor? parsedVendor;
    if (map['vendors'] != null && map['vendors'] is Map<String, dynamic>) {
      parsedVendor = Vendor.fromMap(map['vendors'] as Map<String, dynamic>);
    }

    // Parse joined category name if present
    String? categoryTitle;
    if (map['categories'] != null && map['categories'] is Map<String, dynamic>) {
      categoryTitle = (map['categories'] as Map<String, dynamic>)['name'] as String?;
    }

    return Product(
      id: (map['id']?.toString()) ?? '',
      vendorId: (map['vendor_id']?.toString()) ?? '',
      categoryId: map['category_id']?.toString(),
      categoryName: categoryTitle,
      name: (map['name']?.toString()) ?? 'Untitled Product',
      slug: (map['slug']?.toString()) ?? '',
      description: map['description']?.toString(),
      price: _parseDouble(map['price']),
      compareAtPrice: map['compare_at_price'] != null
          ? _parseDouble(map['compare_at_price'])
          : null,
      costPrice: map['cost_price'] != null
          ? _parseDouble(map['cost_price'])
          : null,
      sku: map['sku']?.toString(),
      stockQuantity: _parseInt(map['stock_quantity']),
      trackInventory: _parseBool(map['track_inventory']),
      status: (map['status']?.toString()) ?? 'draft',
      ratingAvg: _parseDouble(map['rating_avg']),
      ratingCount: _parseInt(map['rating_count']),
      images: parsedImages,
      vendor: parsedVendor,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  final String id;
  final String vendorId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String slug;
  final String? description;
  final double price;
  final double? compareAtPrice;
  final double? costPrice;
  final String? sku;
  final int stockQuantity;
  final bool trackInventory;
  final String status;
  final double ratingAvg;
  final int ratingCount;
  final List<ProductImage> images;
  final Vendor? vendor;
  final DateTime? createdAt;

  /// Returns the primary image URL, or first available image, or null.
  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.firstWhere(
      (img) => img.isPrimary,
      orElse: () => images.first,
    );
    return primary.url;
  }

  /// Alias for primaryImageUrl for compatibility.
  String? get imageUrl => primaryImageUrl;

  /// Whether the product is currently in stock.
  bool get isInStock => !trackInventory || stockQuantity > 0;

  /// Whether stock is considered low (e.g. 5 or fewer).
  bool get isLowStock => trackInventory && stockQuantity > 0 && stockQuantity <= 5;

  /// Whether product has a discount.
  bool get isOnSale =>
      compareAtPrice != null && compareAtPrice! > price;

  /// Discount percentage rounded to whole number.
  int? get discountPercentage {
    if (!isOnSale || compareAtPrice == null || compareAtPrice == 0) return null;
    final pct = ((compareAtPrice! - price) / compareAtPrice!) * 100;
    return pct.round();
  }

  /// Formatted price with Sierra Leone Leone symbol: `SLE 150` or `SLE 150.00`.
  String get formattedPrice {
    if (price == price.roundToDouble()) {
      return 'SLE ${price.toInt()}';
    }
    return 'SLE ${price.toStringAsFixed(2)}';
  }

  /// Formatted compare-at price: `SLE 200`.
  String? get formattedCompareAtPrice {
    if (compareAtPrice == null) return null;
    if (compareAtPrice == compareAtPrice!.roundToDouble()) {
      return 'SLE ${compareAtPrice!.toInt()}';
    }
    return 'SLE ${compareAtPrice!.toStringAsFixed(2)}';
  }

  Product copyWith({
    String? id,
    String? vendorId,
    String? categoryId,
    String? categoryName,
    String? name,
    String? slug,
    String? description,
    double? price,
    double? compareAtPrice,
    double? costPrice,
    String? sku,
    int? stockQuantity,
    bool? trackInventory,
    String? status,
    double? ratingAvg,
    int? ratingCount,
    List<ProductImage>? images,
    Vendor? vendor,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      costPrice: costPrice ?? this.costPrice,
      sku: sku ?? this.sku,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackInventory: trackInventory ?? this.trackInventory,
      status: status ?? this.status,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      images: images ?? this.images,
      vendor: vendor ?? this.vendor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'compare_at_price': compareAtPrice,
      'cost_price': costPrice,
      'sku': sku,
      'stock_quantity': stockQuantity,
      'track_inventory': trackInventory,
      'status': status,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'product_images': images.map((img) => img.toMap()).toList(),
      'vendors': vendor?.toMap(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
