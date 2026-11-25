import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/address/data/models/address_model.dart';
import '../../features/address/presentation/screens/address_form_screen.dart';
import '../../features/address/presentation/screens/saved_addresses_screen.dart';
import '../../features/auth/presentation/controllers/auth_notifier.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/checkout/data/models/checkout_result_model.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/checkout/presentation/screens/order_confirmation_screen.dart';
import '../../features/marketplace/data/models/product_model.dart';
import '../../features/marketplace/presentation/screens/home_screen.dart';
import '../../features/marketplace/presentation/screens/product_catalog_screen.dart';
import '../../features/marketplace/presentation/screens/product_details_screen.dart';
import '../../features/payment/presentation/screens/receipt_screen.dart';
import '../../features/vendor/presentation/screens/vendor_apply_screen.dart';
import '../../features/vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/presentation/screens/vendor_order_detail_screen.dart';
import '../../features/vendor/presentation/screens/vendor_orders_screen.dart';
import '../../features/vendor/presentation/screens/vendor_product_form_screen.dart';
import '../../features/vendor/presentation/screens/vendor_products_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_orders_screen.dart';
import '../../features/admin/presentation/screens/admin_payouts_screen.dart';
import '../../features/admin/presentation/screens/admin_products_screen.dart';
import '../../features/admin/presentation/screens/admin_transactions_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/screens/admin_vendors_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/orders/data/models/customer_order_model.dart';
import '../../features/orders/presentation/screens/customer_order_detail_screen.dart';
import '../../features/orders/presentation/screens/customer_orders_screen.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/profile/presentation/screens/feedback_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/vendor/presentation/screens/vendor_payouts_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';
import '../constants/app_constants.dart';

// ── Route path constants ───────────────────────────────────────────────────

/// All named route paths in one place. Import this class wherever you push
/// or redirect so that path strings are never duplicated.
class Routes {
  Routes._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String emailVerification = '/verify-email';

  // ── Customer — shell ──────────────────────────────────────────────────────
  static const String home = '/home';
  static const String search = '/search';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String profile = '/profile';

  // ── Customer — browse ─────────────────────────────────────────────────────
  static const String categories = '/categories';
  static const String categoryDetail = '/categories/:categoryId';
  static const String vendorList = '/vendors';
  static const String vendorDetail = '/vendors/:vendorId';
  static const String productDetail = '/products/:productId';
  static const String wishlist = '/wishlist';

  // ── Customer — checkout & orders ──────────────────────────────────────────
  static const String checkout = '/checkout';
  static const String checkoutAddress = '/checkout/address';
  static const String checkoutPayment = '/checkout/payment';
  static const String checkoutReview = '/checkout/review';
  static const String orderConfirmation = '/orders/:orderId/confirmation';
  static const String orderDetail = '/orders/:orderId';
  static const String orderTracking = '/orders/:orderId/tracking';
  static const String receipt = '/orders/:orderId/receipt';

  // ── Customer — account ────────────────────────────────────────────────────
  static const String profileEdit = '/profile/edit';
  static const String addresses = '/profile/addresses';
  static const String addressNew = '/profile/addresses/new';
  static const String addressEdit = '/profile/addresses/:addressId';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String feedback = '/profile/feedback';

  // ── Vendor portal ─────────────────────────────────────────────────────────
  static const String vendorDashboard = '/vendor/dashboard';
  static const String vendorOrders = '/vendor/orders';
  static const String vendorOrderDetail = '/vendor/orders/:vendorOrderId';
  static const String vendorProducts = '/vendor/products';
  static const String vendorProductCreate = '/vendor/products/create';
  static const String vendorProductEdit = '/vendor/products/:productId/edit';
  static const String vendorShopSettings = '/vendor/settings';
  static const String vendorAnalytics = '/vendor/analytics';
  static const String vendorApplication = '/vendor/apply';
  static const String vendorPayouts = '/vendor/payouts';

  // ── Admin portal ──────────────────────────────────────────────────────────
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminUserDetail = '/admin/users/:userId';
  static const String adminVendors = '/admin/vendors';
  static const String adminVendorDetail = '/admin/vendors/:vendorId';
  static const String adminProducts = '/admin/products';
  static const String adminOrders = '/admin/orders';
  static const String adminTransactions = '/admin/transactions';
  static const String adminPayouts = '/admin/payouts';
  static const String adminSettings = '/admin/settings';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const String notFound = '/404';
}

// ── Placeholder screen ────────────────────────────────────────────────────

/// Temporary placeholder shown while a real screen is being built.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.routePath});

  final String routePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routePath)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Route: $routePath\n— Coming in Phase 2',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────

/// Central GoRouter configuration for SaloneMarket.
class AppRouter {
  AppRouter._();

  static AuthNotifier? _authNotifier;
  static GoRouter? _routerInstance;

  /// Injects an [AuthNotifier] so that [GoRouter] can react to auth state changes.
  static void setAuthNotifier(AuthNotifier notifier) {
    _authNotifier = notifier;
    _routerInstance = null; // Forces recreate with listenable
  }

  /// Default router instance used by [MaterialApp.router].
  static GoRouter get router {
    _routerInstance ??= createRouter(authNotifier: _authNotifier);
    return _routerInstance!;
  }

  /// Creates a configured [GoRouter] with reactive guards.
  static GoRouter createRouter({AuthNotifier? authNotifier}) {
    final notifier = authNotifier ?? _authNotifier;
    return GoRouter(
      initialLocation: Routes.splash,
      refreshListenable: notifier,
      redirect: (context, state) => _guard(context, state, notifier),
      errorBuilder: (context, state) =>
          const _PlaceholderScreen(routePath: Routes.notFound),
      routes: [
        // ── Auth ────────────────────────────────────────────────────────────
        GoRoute(
          path: Routes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: Routes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: Routes.welcome,
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: Routes.register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: Routes.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: Routes.resetPassword,
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          path: Routes.emailVerification,
          builder: (context, state) => VerifyEmailScreen(
            email: state.extra as String?,
          ),
        ),

        // ── Customer — browse ────────────────────────────────────────────────
        GoRoute(
          path: Routes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: Routes.search,
          builder: (context, state) => ProductCatalogScreen(
            initialQuery: state.uri.queryParameters['q'],
          ),
        ),
        GoRoute(
          path: Routes.cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: Routes.orders,
          builder: (context, state) => const CustomerOrdersScreen(),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: Routes.categories,
          builder: (context, state) => const ProductCatalogScreen(),
        ),
        GoRoute(
          path: Routes.categoryDetail,
          builder: (context, state) => ProductCatalogScreen(
            initialCategoryId: state.pathParameters['categoryId'],
          ),
        ),
        GoRoute(
          path: Routes.vendorList,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.vendorList),
        ),
        GoRoute(
          path: Routes.vendorDetail,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.vendorDetail),
        ),
        GoRoute(
          path: Routes.productDetail,
          builder: (context, state) => ProductDetailsScreen(
            productId: state.pathParameters['productId'] ?? '',
          ),
        ),
        GoRoute(
          path: Routes.wishlist,
          builder: (context, state) => const WishlistScreen(),
        ),

        // ── Customer — checkout ──────────────────────────────────────────────
        GoRoute(
          path: Routes.checkout,
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: Routes.checkoutAddress,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.checkoutAddress),
        ),
        GoRoute(
          path: Routes.checkoutPayment,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.checkoutPayment),
        ),
        GoRoute(
          path: Routes.checkoutReview,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.checkoutReview),
        ),
        GoRoute(
          path: Routes.orderConfirmation,
          builder: (context, state) => OrderConfirmationScreen(
            orderId: state.pathParameters['orderId'] ?? '',
            checkoutResult: state.extra as CheckoutResult?,
          ),
        ),
        GoRoute(
          path: Routes.orderDetail,
          builder: (context, state) => CustomerOrderDetailScreen(
            orderId: state.pathParameters['orderId'] ?? '',
          ),
        ),
        GoRoute(
          path: Routes.orderTracking,
          builder: (context, state) => OrderTrackingScreen(
            orderId: state.pathParameters['orderId'] ?? '',
            initialOrder: state.extra as CustomerOrder?,
          ),
        ),
        GoRoute(
          path: Routes.receipt,
          builder: (context, state) => ReceiptScreen(
            orderId: state.pathParameters['orderId'] ?? '',
          ),
        ),

        // ── Customer — account ───────────────────────────────────────────────
        GoRoute(
          path: Routes.profileEdit,
          builder: (context, state) => const ProfileEditScreen(),
        ),
        GoRoute(
          path: Routes.addresses,
          builder: (context, state) => const SavedAddressesScreen(),
        ),
        GoRoute(
          path: Routes.addressNew,
          builder: (context, state) => const AddressFormScreen(),
        ),
        GoRoute(
          path: Routes.addressEdit,
          builder: (context, state) => AddressFormScreen(
            existingAddress: state.extra as Address?,
          ),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: Routes.feedback,
          builder: (context, state) => FeedbackScreen(
            initialOrderId: state.uri.queryParameters['orderId'],
          ),
        ),

        // ── Vendor portal ────────────────────────────────────────────────────
        GoRoute(
          path: Routes.vendorDashboard,
          builder: (context, state) => const VendorDashboardScreen(),
        ),
        GoRoute(
          path: Routes.vendorOrders,
          builder: (context, state) => const VendorOrdersScreen(),
        ),
        GoRoute(
          path: Routes.vendorOrderDetail,
          builder: (context, state) => VendorOrderDetailScreen(
            vendorOrderId: state.pathParameters['vendorOrderId'] ?? '',
          ),
        ),
        GoRoute(
          path: Routes.vendorProducts,
          builder: (context, state) => const VendorProductsScreen(),
        ),
        GoRoute(
          path: Routes.vendorProductCreate,
          builder: (context, state) => const VendorProductFormScreen(),
        ),
        GoRoute(
          path: Routes.vendorProductEdit,
          builder: (context, state) => VendorProductFormScreen(
            existingProduct: state.extra as Product?,
          ),
        ),
        GoRoute(
          path: Routes.vendorShopSettings,
          builder: (context, state) => const VendorApplyScreen(),
        ),
        GoRoute(
          path: Routes.vendorAnalytics,
          builder: (context, state) => const VendorDashboardScreen(),
        ),
        GoRoute(
          path: Routes.vendorApplication,
          builder: (context, state) => const VendorApplyScreen(),
        ),
        GoRoute(
          path: Routes.vendorPayouts,
          builder: (context, state) => const VendorPayoutsScreen(),
        ),

        // ── Admin portal ─────────────────────────────────────────────────────
        GoRoute(
          path: Routes.adminDashboard,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: Routes.adminUsers,
          builder: (context, state) => const AdminUsersScreen(),
        ),
        GoRoute(
          path: Routes.adminUserDetail,
          builder: (context, state) => const AdminUsersScreen(),
        ),
        GoRoute(
          path: Routes.adminVendors,
          builder: (context, state) => const AdminVendorsScreen(),
        ),
        GoRoute(
          path: Routes.adminVendorDetail,
          builder: (context, state) => const AdminVendorsScreen(),
        ),
        GoRoute(
          path: Routes.adminProducts,
          builder: (context, state) => const AdminProductsScreen(),
        ),
        GoRoute(
          path: Routes.adminOrders,
          builder: (context, state) => const AdminOrdersScreen(),
        ),
        GoRoute(
          path: Routes.adminTransactions,
          builder: (context, state) => const AdminTransactionsScreen(),
        ),
        GoRoute(
          path: Routes.adminPayouts,
          builder: (context, state) => const AdminPayoutsScreen(),
        ),
        GoRoute(
          path: Routes.adminSettings,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.adminSettings),
        ),

        // ── 404 ─────────────────────────────────────────────────────────────
        GoRoute(
          path: Routes.notFound,
          builder: (context, state) =>
              const _PlaceholderScreen(routePath: Routes.notFound),
        ),
      ],
    );
  }

  // ── Auth guard ───────────────────────────────────────────────────────────

  static final _publicRoutes = {
    Routes.splash,
    Routes.onboarding,
    Routes.welcome,
    Routes.login,
    Routes.register,
    Routes.forgotPassword,
    Routes.resetPassword,
    Routes.emailVerification,
    Routes.home,
    Routes.search,
    Routes.categories,
    Routes.categoryDetail,
    Routes.vendorList,
    Routes.vendorDetail,
    Routes.productDetail,
    Routes.cart,
  };

  static final _vendorRoutes = {
    Routes.vendorDashboard,
    Routes.vendorOrders,
    Routes.vendorOrderDetail,
    Routes.vendorProducts,
    Routes.vendorProductCreate,
    Routes.vendorProductEdit,
    Routes.vendorShopSettings,
    Routes.vendorAnalytics,
    Routes.vendorPayouts,
  };

  static final _adminRoutes = {
    Routes.adminDashboard,
    Routes.adminUsers,
    Routes.adminUserDetail,
    Routes.adminVendors,
    Routes.adminVendorDetail,
    Routes.adminProducts,
    Routes.adminOrders,
    Routes.adminTransactions,
    Routes.adminPayouts,
    Routes.adminSettings,
  };

  /// Redirect logic:
  /// 1. Unauthenticated users on protected routes → /login
  /// 2. Authenticated users on auth-only entry points → /home
  /// 3. Non-vendor users on vendor routes → /home
  /// 4. Non-admin users on admin routes → /home
  static String? _guard(
    BuildContext context,
    GoRouterState state,
    AuthNotifier? notifier,
  ) {
    // ── Determine logged-in status ──────────────────────────────────────────
    // Always use the live Supabase session as the source of truth for
    // "is there a session?".  This survives profile-reload transients where
    // notifier.isAuthenticated might momentarily be false while _status ==
    // AuthStatus.loading.
    final hasSupabaseSession = AppConstants.isSupabaseConfigured
        ? Supabase.instance.client.auth.currentSession != null
        : false;

    final isLoggedIn = notifier != null
        ? (notifier.isAuthenticated ||
            notifier.currentUserId != null ||
            hasSupabaseSession)
        : hasSupabaseSession;

    final location = state.matchedLocation;
    final isPublic = _publicRoutes.contains(location);

    if (!isLoggedIn && !isPublic) return Routes.login;

    // Authenticated users should not see auth screens
    final isAuthScreen = {
      Routes.splash,
      Routes.onboarding,
      Routes.welcome,
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
      Routes.resetPassword,
    }.contains(location);

    if (isLoggedIn && isAuthScreen) return Routes.home;

    // ── Role-based guards ───────────────────────────────────────────────────
    // CRITICAL: Never redirect while the profile is still loading.
    // The profile load is async; during that window isAdmin/isVendor are
    // false even for real admins/vendors.  We only redirect once we have a
    // resolved profile (profile != null) and the status is not loading.
    final profileReady =
        notifier != null && notifier.profile != null && !notifier.isLoading;

    if (_vendorRoutes.contains(location)) {
      if (!isLoggedIn) return Routes.login;
      // Wait until profile is fully loaded before making role decisions.
      if (!profileReady) return null;
      if (!notifier!.isVendor && !notifier.isAdmin) return Routes.home;
    }

    if (_adminRoutes.contains(location)) {
      if (!isLoggedIn) return Routes.login;
      // Wait until profile is fully loaded before making role decisions.
      if (!profileReady) return null;
      if (!notifier!.isAdmin) return Routes.home;
    }

    return null; // no redirect
  }
}
