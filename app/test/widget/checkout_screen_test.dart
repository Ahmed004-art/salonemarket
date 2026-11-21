import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/address/data/models/address_model.dart';
import 'package:salonemarket/features/address/data/repositories/address_repository.dart';
import 'package:salonemarket/features/address/presentation/controllers/address_notifier.dart';
import 'package:salonemarket/features/cart/presentation/controllers/cart_notifier.dart';
import 'package:salonemarket/features/checkout/data/models/checkout_result_model.dart';
import 'package:salonemarket/features/checkout/data/repositories/checkout_repository.dart';
import 'package:salonemarket/features/checkout/presentation/controllers/checkout_notifier.dart';
import 'package:salonemarket/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:salonemarket/features/checkout/presentation/screens/order_confirmation_screen.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/models/vendor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCheckoutRepo implements CheckoutRepository {
  @override
  bool get isReady => true;

  @override
  String? get currentUserId => 'mock-user-123';

  @override
  Future<bool> syncCartToSupabase(dynamic items) async => true;

  @override
  Future<CheckoutResult> initiateCheckout({
    required String shippingAddressId,
    String? notes,
    String? idempotencyKey,
  }) async {
    return const CheckoutResult(
      isSuccess: true,
      customerOrderId: 'cord-999',
      vendorOrderIds: ['vord-1'],
      total: 350.0,
    );
  }
}

class MockAddressRepoCheckout implements AddressRepository {
  @override
  bool get isReady => true;

  @override
  String? get currentUserId => 'mock-user-123';

  @override
  Future<AddressResult<List<Address>>> getAddresses() async {
    return const AddressSuccess([
      Address(
        id: 'addr-chk',
        profileId: 'mock-user-123',
        fullName: 'Fatu Conteh',
        phone: '077 445566',
        addressLine1: '25 Regent Road, Hill Station',
        district: 'Western Area Urban',
        isDefault: true,
      ),
    ]);
  }

  @override
  Future<AddressResult<Address>> addAddress(Address address) async =>
      AddressSuccess(address);

  @override
  Future<AddressResult<Address>> updateAddress(Address address) async =>
      AddressSuccess(address);

  @override
  Future<AddressResult<void>> deleteAddress(String addressId) async =>
      const AddressSuccess(null);

  @override
  Future<AddressResult<void>> setDefaultAddress(String addressId) async =>
      const AddressSuccess(null);
}

Widget _wrapWithCheckoutProviders({
  required Widget child,
  CartNotifier? cartNotifier,
  AddressNotifier? addressNotifier,
  CheckoutNotifier? checkoutNotifier,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartNotifier>.value(
        value: cartNotifier ?? CartNotifier(autoLoad: false),
      ),
      ChangeNotifierProvider<AddressNotifier>.value(
        value: addressNotifier ??
            AddressNotifier(repository: MockAddressRepoCheckout()),
      ),
      ChangeNotifierProvider<CheckoutNotifier>.value(
        value: checkoutNotifier ??
            CheckoutNotifier(repository: MockCheckoutRepo()),
      ),
    ],
    child: MaterialApp(
      theme: SaloneMarketTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CheckoutScreen Widget Tests', () {
    testWidgets('renders empty cart message when no items in cart', (tester) async {
      final cart = CartNotifier(autoLoad: false);

      await tester.pumpWidget(
        _wrapWithCheckoutProviders(
          child: const CheckoutScreen(),
          cartNotifier: cart,
        ),
      );
      await tester.pump();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });

    testWidgets('displays address, items, notes and authoritative summary', (tester) async {
      final cart = CartNotifier(autoLoad: false);
      const product = Product(
        id: 'p-checkout',
        vendorId: 'ven-chk',
        name: 'Sierra Honey Jar',
        slug: 'sierra-honey',
        price: 150.0,
        stockQuantity: 10,
        vendor: Vendor(
          id: 'ven-chk',
          profileId: 'pr-chk',
          shopName: 'Makeni Organic Foods',
          slug: 'makeni-foods',
          status: 'active',
        ),
      );

      cart.addItem(product, quantity: 2);

      await tester.pumpWidget(
        _wrapWithCheckoutProviders(
          child: const CheckoutScreen(),
          cartNotifier: cart,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1. Delivery Address'), findsOneWidget);
      expect(find.text('Fatu Conteh'), findsOneWidget);
      expect(find.text('25 Regent Road, Hill Station, Freetown, Western Area Urban'), findsOneWidget);
      expect(find.text('Makeni Organic Foods'), findsOneWidget);
      expect(find.text('Sierra Honey Jar'), findsOneWidget);
      expect(find.text('2 x SLE 150'), findsOneWidget);
      expect(find.text('SLE 300'), findsNWidgets(3)); // item line, subtotal, total
      expect(find.text('Delivery Fee'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Confirm & Place Order (SLE 300)'), findsOneWidget);
    });
  });

  group('OrderConfirmationScreen Widget Tests', () {
    testWidgets('renders celebration icon, order ID, and continue shopping button', (tester) async {
      const result = CheckoutResult(
        isSuccess: true,
        customerOrderId: 'cord-abc-12345678',
        vendorOrderIds: ['vord-1', 'vord-2'],
        total: 450.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SaloneMarketTheme.lightTheme,
          home: const OrderConfirmationScreen(
            orderId: 'cord-abc-12345678',
            checkoutResult: result,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Order Registered!'), findsOneWidget);
      expect(find.text('Status: Pending Payment'), findsOneWidget);
      expect(find.text('cord-abc...'), findsOneWidget);
      expect(find.text('2 order(s)'), findsOneWidget);
      expect(find.text('SLE 450'), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
    });
  });
}
