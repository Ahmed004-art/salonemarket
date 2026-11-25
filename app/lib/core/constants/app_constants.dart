// SaloneMarket — App-wide constants.
// All compile-time secrets are injected via --dart-define, never hard-coded.

// ignore_for_file: avoid_classes_with_only_static_members

/// Top-level application constants.
class AppConstants {
  static const String appName = 'SaloneMarket';
  static const String appVersion = '1.0.0';

  /// Injected at build time via --dart-define=SUPABASE_URL=https://...
  /// or loaded from JSON via --dart-define-from-file=../supabase.dev.json
  static const String _rawSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    // ignore: avoid_redundant_argument_values
    defaultValue: String.fromEnvironment('FLUTTER_SUPABASE_URL'),
  );

  /// Base URL for Supabase, automatically sanitized to remove any accidental trailing paths.
  static String get supabaseUrl {
    var url = _rawSupabaseUrl.trim();
    if (url.endsWith('/rest/v1/')) {
      url = url.substring(0, url.length - '/rest/v1/'.length);
    } else if (url.endsWith('/rest/v1')) {
      url = url.substring(0, url.length - '/rest/v1'.length);
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Injected at build time via --dart-define=SUPABASE_ANON_KEY=...
  /// or loaded from JSON via --dart-define-from-file=../supabase.dev.json
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // ignore: avoid_redundant_argument_values
    defaultValue: String.fromEnvironment('FLUTTER_SUPABASE_ANON_KEY'),
  );

  /// Whether valid Supabase credentials have been injected at compile time.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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
///
/// Valid values are those defined in migration 20261120000001_initial_schema.sql.
/// Do not add values here without also updating the CHECK constraint in a new migration.
class NotificationType {
  static const String orderPlaced = 'order_placed';
  static const String orderConfirmed = 'order_confirmed';
  static const String orderShipped = 'order_shipped';
  static const String orderDelivered = 'order_delivered';
  static const String paymentReceived = 'payment_received';
  static const String paymentFailed = 'payment_failed';
  static const String reviewReceived = 'review_received';
  static const String vendorApproved = 'vendor_approved';
  static const String vendorSuspended = 'vendor_suspended';
  static const String system = 'system';
  // NOTE: 'order_cancelled', 'low_stock', 'new_review' were removed — they are
  // not in the CHECK constraint. Add a migration to extend the constraint first.
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
