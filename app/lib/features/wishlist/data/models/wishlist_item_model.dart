import '../../../marketplace/data/models/product_model.dart';

/// Item in customer wishlist.
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.createdAt,
    required this.product,
  });

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      product: Product.fromMap(map['product'] as Map<String, dynamic>? ?? {}),
    );
  }

  final String id;
  final String customerId;
  final String productId;
  final DateTime createdAt;
  final Product product;
}
