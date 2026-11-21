import 'package:salonemarket/features/marketplace/data/models/product_model.dart';

/// Single item line in the customer shopping cart.
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final productMap = map['product'] as Map<String, dynamic>;
    final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (map['unit_price'] as num?)?.toDouble() ??
        (productMap['price'] as num?)?.toDouble() ??
        0.0;
    return CartItem(
      product: Product.fromMap(productMap),
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  final Product product;
  final int quantity;
  final double unitPrice;

  double get totalPrice => unitPrice * quantity;

  String get formattedTotal {
    if (totalPrice == totalPrice.roundToDouble()) {
      return 'SLE ${totalPrice.toInt()}';
    }
    return 'SLE ${totalPrice.toStringAsFixed(2)}';
  }

  String get formattedTotalPrice => formattedTotal;

  CartItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(),
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}
