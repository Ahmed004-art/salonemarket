// Tests for Finding 3: User-scoped cart persistence.
//
// Covers:
//   - Guest cart persistence and isolation
//   - User A and User B cart isolation
//   - Logout and login transitions
//   - Account switching (A → B, B → A)
//   - Guest cart behaviour after authentication (not merged)
//   - CartStorageService.storageKey() scoping

import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/cart/data/models/cart_item_model.dart';
import 'package:salonemarket/features/cart/data/services/cart_storage_service.dart';
import 'package:salonemarket/features/cart/presentation/controllers/cart_notifier.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/models/vendor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _userA = 'user-aaaa-1111-aaaa-111111111111';
const _userB = 'user-bbbb-2222-bbbb-222222222222';

const _productA = Product(
  id: 'p-a',
  vendorId: 'v-a',
  name: 'Kente Cloth',
  slug: 'kente',
  price: 350.0,
  stockQuantity: 20,
  vendor: Vendor(id: 'v-a', profileId: 'pr-a', shopName: 'Shop A', slug: 'shop-a'),
);

const _productB = Product(
  id: 'p-b',
  vendorId: 'v-b',
  name: 'Groundnut Oil',
  slug: 'groundnut-oil',
  price: 120.0,
  stockQuantity: 50,
  vendor: Vendor(id: 'v-b', profileId: 'pr-b', shopName: 'Shop B', slug: 'shop-b'),
);

const _productGuest = Product(
  id: 'p-guest',
  vendorId: 'v-guest',
  name: 'SIM Card',
  slug: 'sim',
  price: 10.0,
  stockQuantity: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  group('CartStorageService.storageKey() scoping', () {
    test('guest key is distinct from any user key', () {
      final guestKey = CartStorageService.storageKey(null);
      final userAKey = CartStorageService.storageKey(_userA);
      final userBKey = CartStorageService.storageKey(_userB);

      expect(guestKey, isNot(equals(userAKey)));
      expect(guestKey, isNot(equals(userBKey)));
      expect(userAKey, isNot(equals(userBKey)));
    });

    test('same user always produces the same key', () {
      expect(
        CartStorageService.storageKey(_userA),
        equals(CartStorageService.storageKey(_userA)),
      );
    });
  });

  // =========================================================================
  group('Guest cart persistence', () {
    test('guest cart is saved and reloaded correctly', () async {
      final service = CartStorageService();
      const items = [
        CartItem(product: _productGuest, quantity: 3, unitPrice: 10.0),
      ];

      // userId omitted → guest key (default null)
      final saved = await service.saveCart(items);
      expect(saved, isTrue);

      final loaded = await service.loadCart();
      expect(loaded.length, equals(1));
      expect(loaded.first.product.id, equals('p-guest'));
      expect(loaded.first.quantity, equals(3));
    });

    test('clearing guest cart does not affect a user cart', () async {
      final service = CartStorageService();
      const guestItems = [
        CartItem(product: _productGuest, quantity: 1, unitPrice: 10.0),
      ];
      const userItems = [
        CartItem(product: _productA, quantity: 2, unitPrice: 350.0),
      ];

      await service.saveCart(guestItems);              // guest key
      await service.saveCart(userItems, userId: _userA);

      await service.clearCart();                       // guest key

      final guestLoaded = await service.loadCart();
      final userLoaded = await service.loadCart(userId: _userA);

      expect(guestLoaded, isEmpty);
      expect(userLoaded.length, equals(1));
      expect(userLoaded.first.product.id, equals('p-a'));
    });
  });

  // =========================================================================
  group('User A and User B cart isolation', () {
    test('User A cart is not visible to User B', () async {
      final service = CartStorageService();

      await service.saveCart(
        [const CartItem(product: _productA, quantity: 1, unitPrice: 350.0)],
        userId: _userA,
      );

      // User B reads their own (empty) cart
      final userBCart = await service.loadCart(userId: _userB);
      expect(userBCart, isEmpty);
    });

    test('User B cart is not visible to User A', () async {
      final service = CartStorageService();

      await service.saveCart(
        [const CartItem(product: _productB, quantity: 4, unitPrice: 120.0)],
        userId: _userB,
      );

      final userACart = await service.loadCart(userId: _userA);
      expect(userACart, isEmpty);
    });

    test('Both users can persist carts simultaneously without collision', () async {
      final service = CartStorageService();

      await service.saveCart(
        [const CartItem(product: _productA, quantity: 2, unitPrice: 350.0)],
        userId: _userA,
      );
      await service.saveCart(
        [const CartItem(product: _productB, quantity: 5, unitPrice: 120.0)],
        userId: _userB,
      );

      final cartA = await service.loadCart(userId: _userA);
      final cartB = await service.loadCart(userId: _userB);

      expect(cartA.length, equals(1));
      expect(cartA.first.product.id, equals('p-a'));
      expect(cartA.first.quantity, equals(2));

      expect(cartB.length, equals(1));
      expect(cartB.first.product.id, equals('p-b'));
      expect(cartB.first.quantity, equals(5));
    });
  });

  // =========================================================================
  group('CartNotifier — login and logout transitions', () {
    test('setUser loads user-specific cart, clearing previous in-memory state',
        () async {
      final notifier = CartNotifier(autoLoad: false);

      // Start as guest: add a guest item
      await notifier.initialize();
      notifier.addItem(_productGuest);
      expect(notifier.lineCount, equals(1));

      // Simulate User A signing in: cart should switch to User A's persisted
      // cart (empty because nothing was saved for User A yet)
      await notifier.setUser(_userA);
      expect(notifier.lineCount, equals(0));
    });

    test('clearUser wipes in-memory cart and userId, returning to guest state',
        () async {
      final notifier = CartNotifier(autoLoad: false);
      await notifier.setUser(_userA);
      notifier.addItem(_productA);
      expect(notifier.lineCount, equals(1));

      await notifier.clearUser();

      // In-memory cart is now empty (guest state)
      expect(notifier.lineCount, equals(0));
    });

    test('User A cart persists through logout and re-login', () async {
      final notifier = CartNotifier(autoLoad: false);
      await notifier.setUser(_userA);
      notifier.addItem(_productA, quantity: 3);
      expect(notifier.lineCount, equals(1));

      await notifier.clearUser();
      await notifier.setUser(_userA);

      expect(notifier.lineCount, equals(1));
      expect(notifier.getQuantity('p-a'), equals(3));
    });
  });

  // =========================================================================
  group('CartNotifier — account switching safety', () {
    test('User B cannot see User A\'s cart after account switch', () async {
      final service = CartStorageService();

      // Persist a cart for User A
      await service.saveCart(
        [const CartItem(product: _productA, quantity: 2, unitPrice: 350.0)],
        userId: _userA,
      );

      final notifier = CartNotifier(storageService: service, autoLoad: false);

      await notifier.setUser(_userA);
      expect(notifier.lineCount, equals(1));

      // Switch to User B
      await notifier.clearUser();
      await notifier.setUser(_userB);

      expect(notifier.lineCount, equals(0));
    });

    test('User A cart is preserved when User B signs in and out', () async {
      final service = CartStorageService();

      await service.saveCart(
        [const CartItem(product: _productA, quantity: 1, unitPrice: 350.0)],
        userId: _userA,
      );
      await service.saveCart(
        [const CartItem(product: _productB, quantity: 2, unitPrice: 120.0)],
        userId: _userB,
      );

      final notifier = CartNotifier(storageService: service, autoLoad: false);

      await notifier.setUser(_userB);
      expect(notifier.lineCount, equals(1));
      await notifier.clearUser();

      // User A re-signs in — cart must still be intact
      await notifier.setUser(_userA);
      expect(notifier.lineCount, equals(1));
      expect(notifier.getQuantity('p-a'), equals(1));
    });
  });

  // =========================================================================
  group('CartNotifier — guest cart after authentication', () {
    test('guest cart is not merged into user cart on sign-in', () async {
      final service = CartStorageService();

      // Guest adds items before signing in
      await service.saveCart(
        [const CartItem(product: _productGuest, quantity: 1, unitPrice: 10.0)],
      );

      final notifier = CartNotifier(storageService: service, autoLoad: false);

      // Sign in as User A (who has no persisted cart)
      await notifier.setUser(_userA);

      // User A's in-memory cart should be empty; guest items are NOT merged
      expect(notifier.lineCount, equals(0));

      // Guest cart still exists in storage (not destroyed)
      final guestCart = await service.loadCart();
      expect(guestCart.length, equals(1));
    });
  });
}
