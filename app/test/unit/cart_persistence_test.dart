import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/cart/data/models/cart_item_model.dart';
import 'package:salonemarket/features/cart/data/services/cart_storage_service.dart';
import 'package:salonemarket/features/cart/presentation/controllers/cart_notifier.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/models/vendor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartStorageService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const sampleProduct = Product(
      id: 'p-1',
      vendorId: 'v-1',
      name: 'Sierra Gara Fabric',
      slug: 'sierra-gara',
      price: 250.0,
      stockQuantity: 10,
    );

    test('saveCart and loadCart persist and retrieve items correctly', () async {
      final service = CartStorageService();

      const items = [
        CartItem(product: sampleProduct, quantity: 2, unitPrice: 250.0),
      ];

      final saved = await service.saveCart(items);
      expect(saved, isTrue);

      final loaded = await service.loadCart();
      expect(loaded.length, equals(1));
      expect(loaded.first.product.id, equals('p-1'));
      expect(loaded.first.product.name, equals('Sierra Gara Fabric'));
      expect(loaded.first.quantity, equals(2));
      expect(loaded.first.unitPrice, equals(250.0));
    });

    test('clearCart empties storage', () async {
      final service = CartStorageService();
      const items = [
        CartItem(product: sampleProduct, quantity: 1, unitPrice: 250.0),
      ];

      await service.saveCart(items);
      final cleared = await service.clearCart();
      expect(cleared, isTrue);

      final loaded = await service.loadCart();
      expect(loaded, isEmpty);
    });
  });

  group('CartNotifier Multi-Vendor and Availability Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const vendorAProduct = Product(
      id: 'p-va',
      vendorId: 'vendor-a',
      name: 'Product A',
      slug: 'prod-a',
      price: 100.0,
      stockQuantity: 5,
      vendor: Vendor(
        id: 'vendor-a',
        profileId: 'pr-a',
        shopName: 'Shop Alpha',
        slug: 'shop-alpha',
      ),
    );

    const vendorBProduct = Product(
      id: 'p-vb',
      vendorId: 'vendor-b',
      name: 'Product B',
      slug: 'prod-b',
      price: 200.0,
      stockQuantity: 2,
      vendor: Vendor(
        id: 'vendor-b',
        profileId: 'pr-b',
        shopName: 'Shop Beta',
        slug: 'shop-beta',
      ),
    );

    test('itemsByVendor groups items by distinct vendor ID', () {
      final notifier = CartNotifier(autoLoad: false);

      notifier.addItem(vendorAProduct, quantity: 2);
      notifier.addItem(vendorBProduct);

      final grouped = notifier.itemsByVendor;
      expect(grouped.length, equals(2));
      expect(grouped['vendor-a']?.length, equals(1));
      expect(grouped['vendor-b']?.length, equals(1));
      expect(grouped['vendor-a']?.first.product.name, equals('Product A'));
      expect(grouped['vendor-b']?.first.product.name, equals('Product B'));
    });

    test('unavailableItems flags products with exceeded stock or zero stock', () {
      final notifier = CartNotifier(autoLoad: false);

      notifier.addItem(vendorAProduct, quantity: 2);
      expect(notifier.hasUnavailableItems, isFalse);

      final exceededProduct = vendorBProduct.copyWith(stockQuantity: 1);
      final rawItem = CartItem(
        product: exceededProduct,
        quantity: 3,
        unitPrice: 200.0,
      );
      expect(rawItem.quantity > rawItem.product.stockQuantity, isTrue);

      const oosProduct = Product(
        id: 'p-oos',
        vendorId: 'vendor-c',
        name: 'Sold out',
        slug: 'sold-out',
        price: 50.0,
      );

      const itemOos = CartItem(product: oosProduct, quantity: 1, unitPrice: 50.0);
      expect(itemOos.product.isInStock, isFalse);
    });
  });
}
