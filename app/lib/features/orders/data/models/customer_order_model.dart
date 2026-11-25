/// Model representing a customer order, its line items, and fulfillment state.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.total,
    this.paymentMethod,
    required this.paymentStatus,
    this.shippingAddressId,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.shippingAddress,
    this.vendorOrders = const [],
  });

  factory CustomerOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['order_items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => CustomerOrderItem.fromMap(item as Map<String, dynamic>))
        .toList();

    final rawVendorOrders = map['vendor_orders'] as List<dynamic>? ?? [];
    final vendorOrdersList = rawVendorOrders
        .map((vo) => CustomerVendorOrder.fromMap(vo as Map<String, dynamic>))
        .toList();

    return CustomerOrder(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending_payment',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      platformFee: (map['platform_fee'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? 'pending',
      shippingAddressId: map['shipping_address_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      items: itemsList,
      shippingAddress: map['shipping_address'] as Map<String, dynamic>?,
      vendorOrders: vendorOrdersList,
    );
  }

  final String id;
  final String customerId;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double platformFee;
  final double total;
  final String? paymentMethod;
  final String paymentStatus;
  final String? shippingAddressId;
  final String? notes;
  final DateTime createdAt;
  final List<CustomerOrderItem> items;
  final Map<String, dynamic>? shippingAddress;
  final List<CustomerVendorOrder> vendorOrders;

  bool get isPaid => paymentStatus == 'paid';
  bool get isFulfilled => status == 'fulfilled';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => !isFulfilled && !isCancelled;

  String get formattedTotal => 'SLE ${total.toStringAsFixed(2)}';
  String get formattedSubtotal => 'SLE ${subtotal.toStringAsFixed(2)}';
  String get formattedDeliveryFee => 'SLE ${deliveryFee.toStringAsFixed(2)}';

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}

/// Immutable snapshot of an ordered product item.
class CustomerOrderItem {
  const CustomerOrderItem({
    required this.id,
    required this.customerOrderId,
    required this.vendorOrderId,
    this.productId,
    required this.vendorId,
    required this.productName,
    this.productImageUrl,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory CustomerOrderItem.fromMap(Map<String, dynamic> map) {
    return CustomerOrderItem(
      id: map['id']?.toString() ?? '',
      customerOrderId: map['customer_order_id']?.toString() ?? '',
      vendorOrderId: map['vendor_order_id']?.toString() ?? '',
      productId: map['product_id']?.toString(),
      vendorId: map['vendor_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Item',
      productImageUrl: map['product_image_url']?.toString(),
      sku: map['sku']?.toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (map['line_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String id;
  final String customerOrderId;
  final String vendorOrderId;
  final String? productId;
  final String vendorId;
  final String productName;
  final String? productImageUrl;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  String get formattedPrice => 'SLE ${unitPrice.toStringAsFixed(2)}';
  String get formattedTotal => 'SLE ${lineTotal.toStringAsFixed(2)}';
}

/// Per-vendor sub-order in a multi-vendor customer order.
class CustomerVendorOrder {
  const CustomerVendorOrder({
    required this.id,
    required this.vendorId,
    required this.status,
    required this.subtotal,
    this.notes,
  });

  factory CustomerVendorOrder.fromMap(Map<String, dynamic> map) {
    return CustomerVendorOrder(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'awaiting_payment',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes']?.toString(),
    );
  }

  final String id;
  final String vendorId;
  final String status;
  final double subtotal;
  final String? notes;
}
