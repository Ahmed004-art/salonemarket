/// Model representing aggregate vendor statistics from PostgreSQL RPC.
class VendorDashboardStats {
  const VendorDashboardStats({
    required this.vendorId,
    required this.shopName,
    required this.status,
    required this.totalProducts,
    required this.activeProducts,
    required this.pendingOrders,
    required this.completedOrders,
    required this.totalSales,
    required this.todaySales,
    required this.weekSales,
    required this.monthSales,
    required this.recentOrders,
  });

  factory VendorDashboardStats.fromMap(Map<String, dynamic> map) {
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

    final rawRecent = map['recent_orders'];
    final recentList = <VendorRecentOrder>[];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        if (item is Map<String, dynamic>) {
          recentList.add(VendorRecentOrder.fromMap(item));
        }
      }
    }

    return VendorDashboardStats(
      vendorId: map['vendor_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      totalProducts: parseInt(map['total_products']),
      activeProducts: parseInt(map['active_products']),
      pendingOrders: parseInt(map['pending_orders']),
      completedOrders: parseInt(map['completed_orders']),
      totalSales: parseDouble(map['total_sales']),
      todaySales: parseDouble(map['today_sales']),
      weekSales: parseDouble(map['week_sales']),
      monthSales: parseDouble(map['month_sales']),
      recentOrders: recentList,
    );
  }

  final String vendorId;
  final String shopName;
  final String status;
  final int totalProducts;
  final int activeProducts;
  final int pendingOrders;
  final int completedOrders;
  final double totalSales;
  final double todaySales;
  final double weekSales;
  final double monthSales;
  final List<VendorRecentOrder> recentOrders;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isSuspended => status == 'suspended';
}

/// Lightweight snapshot of recent vendor orders for the dashboard list.
class VendorRecentOrder {
  const VendorRecentOrder({
    required this.id,
    required this.customerOrderId,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.vendorPayout,
    required this.customerName,
    required this.itemCount,
    required this.createdAt,
  });

  factory VendorRecentOrder.fromMap(Map<String, dynamic> map) {
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

    DateTime? parsedDate;
    if (map['created_at'] != null) {
      parsedDate = DateTime.tryParse(map['created_at'].toString());
    }

    return VendorRecentOrder(
      id: map['id']?.toString() ?? '',
      customerOrderId: map['customer_order_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'awaiting_payment',
      paymentStatus: map['payment_status']?.toString() ?? 'pending',
      subtotal: parseDouble(map['subtotal']),
      vendorPayout: parseDouble(map['vendor_payout']),
      customerName: map['customer_name']?.toString() ?? 'Shopper',
      itemCount: parseInt(map['item_count']),
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  final String id;
  final String customerOrderId;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double vendorPayout;
  final String customerName;
  final int itemCount;
  final DateTime createdAt;
}
