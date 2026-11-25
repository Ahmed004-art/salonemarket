/// Real platform statistics model returned from PostgreSQL admin_get_platform_stats RPC.
class AdminPlatformStats {
  const AdminPlatformStats({
    required this.totalCustomers,
    required this.totalVendors,
    required this.pendingVendors,
    required this.activeVendors,
    required this.suspendedVendors,
    required this.totalProducts,
    required this.activeProducts,
    required this.flaggedProducts,
    required this.totalOrders,
    required this.totalGmv,
    required this.todayGmv,
    required this.weekGmv,
    required this.monthGmv,
    required this.reconciliationAlerts,
  });

  factory AdminPlatformStats.fromMap(Map<String, dynamic> map) {
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

    return AdminPlatformStats(
      totalCustomers: parseInt(map['total_customers']),
      totalVendors: parseInt(map['total_vendors']),
      pendingVendors: parseInt(map['pending_vendors']),
      activeVendors: parseInt(map['active_vendors']),
      suspendedVendors: parseInt(map['suspended_vendors']),
      totalProducts: parseInt(map['total_products']),
      activeProducts: parseInt(map['active_products']),
      flaggedProducts: parseInt(map['flagged_products']),
      totalOrders: parseInt(map['total_orders']),
      totalGmv: parseDouble(map['total_gmv']),
      todayGmv: parseDouble(map['today_gmv']),
      weekGmv: parseDouble(map['week_gmv']),
      monthGmv: parseDouble(map['month_gmv']),
      reconciliationAlerts: parseInt(map['reconciliation_alerts']),
    );
  }

  final int totalCustomers;
  final int totalVendors;
  final int pendingVendors;
  final int activeVendors;
  final int suspendedVendors;
  final int totalProducts;
  final int activeProducts;
  final int flaggedProducts;
  final int totalOrders;
  final double totalGmv;
  final double todayGmv;
  final double weekGmv;
  final double monthGmv;
  final int reconciliationAlerts;
}
