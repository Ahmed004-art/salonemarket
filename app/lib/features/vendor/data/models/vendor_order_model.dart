/// Detailed vendor order model with line items and customer information.
class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.customerOrderId,
    required this.vendorId,
    required this.customerId,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.commissionAmount,
    required this.vendorPayout,
    required this.createdAt,
    this.notes,
    this.customerName,
    this.customerPhone,
    this.paymentStatus = 'pending',
    this.paymentMethod,
    this.shippingAddress,
    this.items = const [],
  });

  factory VendorOrder.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final rawItems = map['order_items'];
    final itemsList = <VendorOrderItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(VendorOrderItem.fromMap(item));
        }
      }
    }

    // Customer profile info if joined
    String? custName;
    String? custPhone;
    if (map['profiles'] is Map<String, dynamic>) {
      final p = map['profiles'] as Map<String, dynamic>;
      custName = p['full_name'] as String?;
      custPhone = p['phone'] as String?;
    }

    // Customer order info if joined
    String payStatus = 'pending';
    String? payMethod;
    String? addressStr;
    if (map['customer_orders'] is Map<String, dynamic>) {
      final co = map['customer_orders'] as Map<String, dynamic>;
      payStatus = co['payment_status']?.toString() ?? 'pending';
      payMethod = co['payment_method']?.toString();
      if (co['addresses'] is Map<String, dynamic>) {
        final a = co['addresses'] as Map<String, dynamic>;
        addressStr = '${a['street_address'] ?? ''}, ${a['city'] ?? ''}';
      }
    }

    return VendorOrder(
      id: map['id']?.toString() ?? '',
      customerOrderId: map['customer_order_id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'awaiting_payment',
      subtotal: parseDouble(map['subtotal']),
      deliveryFee: parseDouble(map['delivery_fee']),
      commissionAmount: parseDouble(map['commission_amount']),
      vendorPayout: parseDouble(map['vendor_payout']),
      notes: map['notes']?.toString(),
      customerName: custName ?? 'Shopper',
      customerPhone: custPhone,
      paymentStatus: payStatus,
      paymentMethod: payMethod,
      shippingAddress: addressStr,
      items: itemsList,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String customerOrderId;
  final String vendorId;
  final String customerId;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double commissionAmount;
  final double vendorPayout;
  final String? notes;
  final String? customerName;
  final String? customerPhone;
  final String paymentStatus;
  final String? paymentMethod;
  final String? shippingAddress;
  final List<VendorOrderItem> items;
  final DateTime createdAt;

  bool get isPaid => paymentStatus == 'paid';

  /// Whether the vendor can move status forward
  List<String> get allowableNextStatuses {
    if (!isPaid) return const []; // Unpaid orders cannot be advanced by vendor
    switch (status) {
      case 'confirmed':
        return const ['processing', 'cancelled'];
      case 'processing':
        return const ['ready_for_pickup', 'shipped', 'cancelled'];
      case 'ready_for_pickup':
        return const ['shipped', 'delivered'];
      case 'shipped':
        return const ['delivered'];
      default:
        return const [];
    }
  }
}

/// Item inside a vendor order
class VendorOrderItem {
  const VendorOrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productImageUrl,
    this.sku,
  });

  factory VendorOrderItem.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return VendorOrderItem(
      id: map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Item',
      productImageUrl: map['product_image_url']?.toString(),
      sku: map['sku']?.toString(),
      quantity: parseInt(map['quantity']),
      unitPrice: parseDouble(map['unit_price']),
      lineTotal: parseDouble(map['line_total']),
    );
  }

  final String id;
  final String productName;
  final String? productImageUrl;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}
