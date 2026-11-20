// SaloneMarket — App-wide constants.
// All compile-time secrets are injected via --dart-define, never hard-coded.

// ignore_for_file: avoid_classes_with_only_static_members

/// Top-level application constants.
class AppConstants {
  static const String appName = 'SaloneMarket';
  static const String appVersion = '1.0.0';

  /// Injected at build time: flutter run --dart-define=SUPABASE_URL=https://...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Injected at build time: flutter run --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String currency = 'SLL';
  static const String currencySymbol = 'Le';
  static const String currencyName = 'Sierra Leonean Leone';
}

/// User role identifiers matching the `profiles.role` CHECK constraint.
class Roles {
  static const String customer = 'customer';
  static const String vendor = 'vendor';
  static const String admin = 'admin';
}

/// Order status values matching the `customer_orders.status` CHECK constraint.
class OrderStatus {
  static const String pendingPayment = 'pending_payment';
  static const String paymentFailed = 'payment_failed';
  static const String confirmed = 'confirmed';
  static const String partiallyFulfilled = 'partially_fulfilled';
  static const String fulfilled = 'fulfilled';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';
}

/// Payment status values matching the `customer_orders.payment_status` CHECK constraint.
class PaymentStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String paid = 'paid';
  static const String failed = 'failed';
  static const String refunded = 'refunded';
}

/// Supported payment method identifiers.
class PaymentMethod {
  /// Simulated payment — no real money moves. Academic project only.
  static const String simulated = 'simulated';
  static const String mobileMoney = 'mobile_money';
  static const String cashOnDelivery = 'cash_on_delivery';
}

/// Notification type identifiers matching `notifications.type` CHECK constraint.
class NotificationType {
  static const String orderPlaced = 'order_placed';
  static const String orderConfirmed = 'order_confirmed';
  static const String orderShipped = 'order_shipped';
  static const String orderDelivered = 'order_delivered';
  static const String orderCancelled = 'order_cancelled';
  static const String paymentReceived = 'payment_received';
  static const String paymentFailed = 'payment_failed';
  static const String newReview = 'new_review';
  static const String vendorApproved = 'vendor_approved';
  static const String vendorSuspended = 'vendor_suspended';
  static const String lowStock = 'low_stock';
  static const String system = 'system';
}

/// Supabase Storage bucket names.
class StorageBuckets {
  static const String products = 'product-images';
  static const String avatars = 'avatars';
}

/// Supabase Edge Function names (must match function directory names).
class FunctionNames {
  static const String initiateCheckout = 'initiate-checkout';
  static const String processPayment = 'process-payment';
  static const String generateReceipt = 'generate-receipt';
}
