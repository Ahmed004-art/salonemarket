import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/cart/presentation/controllers/cart_notifier.dart';
import 'package:salonemarket/features/marketplace/data/models/category_model.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/models/vendor_model.dart';

void main() {
  group('Category Model Tests', () {
    test('fromMap parses valid category payload', () {
      final map = {
        'id': 'cat-1',
        'name': 'Electronics & Mobile',
        'slug': 'electronics-mobile',
        'sort_order': 1,
        'is_active': true,
      };

      final category = Category.fromMap(map);

      expect(category.id, equals('cat-1'));
      expect(category.name, equals('Electronics & Mobile'));
      expect(category.slug, equals('electronics-mobile'));
      expect(category.sortOrder, equals(1));
      expect(category.isActive, isTrue);
    });
  });

  group('Vendor Model Tests', () {
    test('fromMap parses vendor and calculates verification status', () {
      final map = {
        'id': 'ven-1',
        'profile_id': 'prof-1',
        'shop_name': 'Kroo Town Electronics',
        'slug': 'kroo-town-electronics',
        'location': 'Freetown, Sierra Leone',
        'status': 'active',
        'rating_avg': 4.75,
        'rating_count': 24,
      };

      final vendor = Vendor.fromMap(map);

      expect(vendor.id, equals('ven-1'));
      expect(vendor.shopName, equals('Kroo Town Electronics'));
      expect(vendor.isVerified, isTrue);
      expect(vendor.ratingAvg, equals(4.75));
      expect(vendor.ratingCount, equals(24));
    });
  });

  group('Product Model Tests', () {
    test('fromMap correctly calculates price formatting and stock flags', () {
      final map = {
        'id': 'prod-1',
        'vendor_id': 'ven-1',
        'name': 'Tecno Spark 20 Pro',
        'slug': 'tecno-spark-20-pro',
        'price': 2500.0,
        'compare_at_price': 3000.0,
        'stock_quantity': 4,
        'track_inventory': true,
        'status': 'active',
        'rating_avg': 4.8,
        'rating_count': 15,
        'product_images': [
          {
            'id': 'img-1',
            'product_id': 'prod-1',
            'url': 'https://example.com/front.jpg',
            'is_primary': true,
            'sort_order': 0,
          },
          {
            'id': 'img-2',
            'product_id': 'prod-1',
            'url': 'https://example.com/back.jpg',
            'is_primary': false,
            'sort_order': 1,
          },
        ],
        'vendors': {
          'id': 'ven-1',
          'shop_name': 'Kroo Town Electronics',
          'slug': 'kroo-town-electronics',
          'location': 'Freetown, Sierra Leone',
          'status': 'active',
        },
      };

      final product = Product.fromMap(map);

      expect(product.id, equals('prod-1'));
      expect(product.name, equals('Tecno Spark 20 Pro'));
      expect(product.formattedPrice, equals('SLE 2500'));
      expect(product.formattedCompareAtPrice, equals('SLE 3000'));
      expect(product.isOnSale, isTrue);
      expect(product.discountPercentage, equals(17)); // (3000-2500)/3000 = 16.66% -> 17%
      expect(product.isInStock, isTrue);
      expect(product.isLowStock, isTrue); // <= 5
      expect(product.primaryImageUrl, equals('https://example.com/front.jpg'));
      expect(product.images.length, equals(2));
      expect(product.vendor?.shopName, equals('Kroo Town Electronics'));
    });

    test('price formatting handles fractional decimals cleanly', () {
      const product = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Item',
        slug: 'item',
        price: 150.50,
      );

      expect(product.formattedPrice, equals('SLE 150.50'));
    });

    test('fromMap safely parses malformed strings, nulls, and numeric fields', () {
      final malformedMap = {
        'id': 'p-malformed',
        'vendor_id': 'v-1',
        'name': null,
        'slug': null,
        'price': '450.75', // String instead of num
        'compare_at_price': '500.0',
        'cost_price': null,
        'stock_quantity': '15', // String integer
        'track_inventory': 'true', // String boolean
        'status': null,
        'rating_avg': '4.85',
        'rating_count': '32',
        'product_images': [
          {
            'id': 12345, // int instead of String
            'product_id': 'p-malformed',
            'url': 'https://example.com/img.png',
            'sort_order': '1',
            'is_primary': 'true',
          }
        ],
        'vendors': {
          'id': 'v-1',
          'shop_name': null,
          'rating_avg': '4.2',
          'rating_count': '10',
          'commission_rate': '0.08',
        },
      };

      final product = Product.fromMap(malformedMap);

      expect(product.id, equals('p-malformed'));
      expect(product.name, equals('Untitled Product'));
      expect(product.price, equals(450.75));
      expect(product.compareAtPrice, equals(500.0));
      expect(product.stockQuantity, equals(15));
      expect(product.trackInventory, isTrue);
      expect(product.status, equals('draft'));
      expect(product.ratingAvg, equals(4.85));
      expect(product.ratingCount, equals(32));
      expect(product.images.first.id, equals('12345'));
      expect(product.images.first.sortOrder, equals(1));
      expect(product.images.first.isPrimary, isTrue);
      expect(product.vendor?.shopName, equals('Verified Seller'));
      expect(product.vendor?.ratingAvg, equals(4.2));
      expect(product.vendor?.ratingCount, equals(10));
      expect(product.vendor?.commissionRate, equals(0.08));
    });
  });

  group('CartNotifier State Tests', () {
    late CartNotifier cart;

    setUp(() {
      cart = CartNotifier(autoLoad: false);
    });

    test('initial cart is empty', () {
      expect(cart.itemCount, equals(0));
      expect(cart.lineCount, equals(0));
      expect(cart.subtotal, equals(0.0));
    });

    test('addItem increments counts and calculates subtotal', () {
      const product1 = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Shirt',
        slug: 'shirt',
        price: 100.0,
        stockQuantity: 10,
      );

      cart.addItem(product1, quantity: 2);

      expect(cart.itemCount, equals(2));
      expect(cart.lineCount, equals(1));
      expect(cart.subtotal, equals(200.0));
      expect(cart.formattedSubtotal, equals('SLE 200'));

      // Adding the same product again increases quantity
      cart.addItem(product1);
      expect(cart.itemCount, equals(3));
      expect(cart.subtotal, equals(300.0));
    });

    test('updateQuantity modifies quantity or removes item when zero', () {
      const product1 = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Shirt',
        slug: 'shirt',
        price: 100.0,
        stockQuantity: 10,
      );

      cart.addItem(product1, quantity: 2);
      cart.updateQuantity('p-1', 5);
      expect(cart.itemCount, equals(5));

      cart.updateQuantity('p-1', 0);
      expect(cart.itemCount, equals(0));
      expect(cart.containsProduct('p-1'), isFalse);
    });

    test('addItem rejects out-of-stock products', () {
      const outOfStockProduct = Product(
        id: 'p-oos',
        vendorId: 'v-1',
        name: 'Sold Out Dress',
        slug: 'sold-out-dress',
        price: 300.0,
      );

      final added = cart.addItem(outOfStockProduct);
      expect(added, isFalse);
      expect(cart.itemCount, equals(0));
      expect(cart.containsProduct('p-oos'), isFalse);
    });

    test('addItem and updateQuantity clamp to available stock inventory', () {
      const limitedProduct = Product(
        id: 'p-ltd',
        vendorId: 'v-1',
        name: 'Limited Shoes',
        slug: 'limited-shoes',
        price: 500.0,
        stockQuantity: 3,
      );

      // Add 2 items (success)
      expect(cart.addItem(limitedProduct, quantity: 2), isTrue);
      expect(cart.getQuantity('p-ltd'), equals(2));

      // Adding 5 more should clamp to maximum 3
      expect(cart.addItem(limitedProduct, quantity: 5), isTrue);
      expect(cart.getQuantity('p-ltd'), equals(3));

      // Trying to add again when already at max stock (3) should reject
      expect(cart.addItem(limitedProduct), isFalse);
      expect(cart.getQuantity('p-ltd'), equals(3));

      // updateQuantity clamping
      cart.updateQuantity('p-ltd', 10);
      expect(cart.getQuantity('p-ltd'), equals(3));

      // updateQuantity with negative or zero removes item
      cart.updateQuantity('p-ltd', -1);
      expect(cart.containsProduct('p-ltd'), isFalse);
    });

    test('clear empties the entire cart', () {
      const product1 = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Shirt',
        slug: 'shirt',
        price: 100.0,
        stockQuantity: 10,
      );

      cart.addItem(product1, quantity: 2);
      expect(cart.itemCount, equals(2));

      cart.clear();
      expect(cart.itemCount, equals(0));
      expect(cart.subtotal, equals(0.0));
    });
  });
}
