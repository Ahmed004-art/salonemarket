import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salonemarket/core/theme/app_theme.dart';
import 'package:salonemarket/features/cart/presentation/controllers/cart_notifier.dart';
import 'package:salonemarket/features/cart/presentation/screens/cart_screen.dart';
import 'package:salonemarket/features/marketplace/data/models/category_model.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/models/vendor_model.dart';
import 'package:salonemarket/features/marketplace/data/repositories/marketplace_repository.dart';
import 'package:salonemarket/features/marketplace/presentation/controllers/marketplace_notifier.dart';
import 'package:salonemarket/features/marketplace/presentation/screens/home_screen.dart';
import 'package:salonemarket/features/marketplace/presentation/screens/product_catalog_screen.dart';
import 'package:salonemarket/features/marketplace/presentation/widgets/product_card.dart';

class MockMarketplaceRepo implements MarketplaceRepository {
  final List<Category> categories = [
    const Category(
      id: 'cat-1',
      name: 'Electronics & Mobile',
      slug: 'electronics-mobile',
    ),
    const Category(
      id: 'cat-2',
      name: 'Fashion & Clothing',
      slug: 'fashion-clothing',
    ),
  ];

  final List<Product> products = [
    const Product(
      id: 'p-1',
      vendorId: 'v-1',
      name: 'Infinix Hot 40',
      slug: 'infinix-hot-40',
      price: 1800.0,
      compareAtPrice: 2000.0,
      stockQuantity: 10,
      categoryId: 'cat-1',
      categoryName: 'Electronics & Mobile',
      vendor: Vendor(
        id: 'v-1',
        profileId: 'pr-1',
        shopName: 'Salone Gadgets',
        slug: 'salone-gadgets',
        location: 'Freetown',
        status: 'active',
      ),
    ),
    const Product(
      id: 'p-2',
      vendorId: 'v-2',
      name: 'African Print Dress',
      slug: 'african-print-dress',
      price: 350.0,
      stockQuantity: 5,
      categoryId: 'cat-2',
      categoryName: 'Fashion & Clothing',
      vendor: Vendor(
        id: 'v-2',
        profileId: 'pr-2',
        shopName: 'Sierra Styles',
        slug: 'sierra-styles',
        location: 'Bo',
        status: 'active',
      ),
    ),
  ];

  @override
  bool get isReady => true;

  @override
  Future<MarketplaceResult<List<Category>>> getCategories({
    bool topLevelOnly = true,
  }) async {
    return MarketplaceSuccess(categories);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getFeaturedProducts({
    int limit = 8,
  }) async {
    return MarketplaceSuccess(products);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getPopularProducts({
    int limit = 8,
  }) async {
    return MarketplaceSuccess(products);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getProducts({
    String? categoryId,
    String? searchQuery,
    String sortBy = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    return MarketplaceSuccess(products);
  }

  @override
  Future<MarketplaceResult<Product>> getProductById(String id) async {
    return MarketplaceSuccess(products.first);
  }
}

Widget _wrapWithProviders({
  required Widget child,
  MarketplaceNotifier? marketplaceNotifier,
  CartNotifier? cartNotifier,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MarketplaceNotifier>.value(
        value: marketplaceNotifier ??
            MarketplaceNotifier(repository: MockMarketplaceRepo()),
      ),
      ChangeNotifierProvider<CartNotifier>.value(
        value: cartNotifier ?? CartNotifier(autoLoad: false),
      ),
    ],
    child: MaterialApp(
      theme: SaloneMarketTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('renders marketplace app bar, search bar, and hero banner',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const HomeScreen()));
      await tester.pump();

      expect(find.text('SALONEMARKET'), findsOneWidget);
      expect(find.text('Freetown & Nationwide'), findsOneWidget);
      expect(find.text('Search electronics, fashion, food...'), findsOneWidget);
      expect(find.text('SIERRA LEONE SHOWCASE'), findsOneWidget);
      expect(find.text('Direct from Local\nMerchants & Makers'), findsOneWidget);
    });

    testWidgets('renders bottom navigation with five tabs', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const HomeScreen()));
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('ProductCard Widget Tests', () {
    testWidgets('displays title, formatted price, vendor, and quick-add button',
        (tester) async {
      const product = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Sierra Leone Coffee Beans',
        slug: 'sl-coffee',
        price: 85.0,
        compareAtPrice: 100.0,
        stockQuantity: 12,
        vendor: Vendor(
          id: 'v-1',
          profileId: 'pr-1',
          shopName: 'Kenema Roasters',
          slug: 'kenema-roasters',
          status: 'active',
        ),
      );

      final cartNotifier = CartNotifier(autoLoad: false);

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const Scaffold(
            body: SizedBox(height: 250, child: ProductCard(product: product)),
          ),
          cartNotifier: cartNotifier,
        ),
      );

      expect(find.text('Sierra Leone Coffee Beans'), findsOneWidget);
      expect(find.text('SLE 85'), findsOneWidget);
      expect(find.text('SLE 100'), findsOneWidget);
      expect(find.text('Kenema Roasters'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);

      // Tap quick add button
      await tester.tap(find.byIcon(Icons.add_shopping_cart));
      await tester.pump();

      expect(cartNotifier.itemCount, equals(1));
      expect(cartNotifier.containsProduct('p-1'), isTrue);
    });
  });

  group('ProductCatalogScreen Widget Tests', () {
    testWidgets('renders search field, sort button, and category chips',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(child: const ProductCatalogScreen()),
      );
      await tester.pump();

      expect(find.text('Search products or vendors...'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
    });
  });

  group('CartScreen Widget Tests', () {
    testWidgets('renders empty cart state when cart has no items',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(child: const CartScreen()),
      );
      await tester.pump();

      expect(find.text('Shopping Cart (0)'), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Explore Marketplace'), findsOneWidget);
    });

    testWidgets('renders cart items, SLE subtotal, and updates quantity',
        (tester) async {
      final cartNotifier = CartNotifier(autoLoad: false);
      const product = Product(
        id: 'p-1',
        vendorId: 'v-1',
        name: 'Gara Tie Dye Shirt',
        slug: 'gara-shirt',
        price: 250.0,
        stockQuantity: 5,
        vendor: Vendor(
          id: 'v-1',
          profileId: 'pr-1',
          shopName: 'Krootown Crafts',
          slug: 'krootown-crafts',
          status: 'active',
        ),
      );

      cartNotifier.addItem(product, quantity: 2);

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const CartScreen(),
          cartNotifier: cartNotifier,
        ),
      );
      await tester.pump();

      expect(find.text('Shopping Cart (2)'), findsOneWidget);
      expect(find.text('Gara Tie Dye Shirt'), findsOneWidget);
      expect(find.text('Krootown Crafts'), findsOneWidget);
      expect(find.text('SLE 500'), findsNWidgets(2)); // line item total and subtotal

      // Increment quantity
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(cartNotifier.getQuantity('p-1'), equals(3));
      expect(find.text('Shopping Cart (3)'), findsOneWidget);
      expect(find.text('SLE 750'), findsNWidgets(2));
    });
  });
}
