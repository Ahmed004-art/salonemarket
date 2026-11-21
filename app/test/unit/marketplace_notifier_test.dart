import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/features/marketplace/data/models/category_model.dart';
import 'package:salonemarket/features/marketplace/data/models/product_model.dart';
import 'package:salonemarket/features/marketplace/data/repositories/marketplace_repository.dart';
import 'package:salonemarket/features/marketplace/presentation/controllers/marketplace_notifier.dart';

class FakeMarketplaceRepository implements MarketplaceRepository {
  bool shouldSucceed = true;
  String errorMessage = 'Simulated error';

  final List<Category> mockCategories = [
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

  final List<Product> mockProducts = [
    const Product(
      id: 'prod-1',
      vendorId: 'ven-1',
      name: 'Tecno Camon 30',
      slug: 'tecno-camon-30',
      price: 3200.0,
      categoryId: 'cat-1',
      ratingAvg: 4.9,
      ratingCount: 18,
    ),
    const Product(
      id: 'prod-2',
      vendorId: 'ven-2',
      name: 'Gara Tie Dye Shirt',
      slug: 'gara-tie-dye-shirt',
      price: 250.0,
      categoryId: 'cat-2',
      ratingAvg: 4.8,
      ratingCount: 30,
    ),
  ];

  @override
  bool get isReady => true;

  @override
  Future<MarketplaceResult<List<Category>>> getCategories({
    bool topLevelOnly = true,
  }) async {
    if (shouldSucceed) {
      return MarketplaceSuccess(mockCategories);
    }
    return MarketplaceFailure(errorMessage);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getFeaturedProducts({
    int limit = 8,
  }) async {
    if (shouldSucceed) {
      return MarketplaceSuccess(mockProducts);
    }
    return MarketplaceFailure(errorMessage);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getPopularProducts({
    int limit = 8,
  }) async {
    if (shouldSucceed) {
      return MarketplaceSuccess(mockProducts);
    }
    return MarketplaceFailure(errorMessage);
  }

  @override
  Future<MarketplaceResult<List<Product>>> getProducts({
    String? categoryId,
    String? searchQuery,
    String sortBy = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    if (!shouldSucceed) {
      return MarketplaceFailure(errorMessage);
    }

    var list = List<Product>.from(mockProducts);
    if (categoryId != null) {
      list = list.where((p) => p.categoryId == categoryId).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(searchQuery.toLowerCase()),)
          .toList();
    }
    return MarketplaceSuccess(list);
  }

  @override
  Future<MarketplaceResult<Product>> getProductById(String id) async {
    if (!shouldSucceed) {
      return MarketplaceFailure(errorMessage);
    }
    final match = mockProducts.firstWhere(
      (p) => p.id == id,
      orElse: () => mockProducts.first,
    );
    return MarketplaceSuccess(match);
  }
}

void main() {
  group('MarketplaceNotifier Tests', () {
    late FakeMarketplaceRepository fakeRepo;
    late MarketplaceNotifier notifier;

    setUp(() {
      fakeRepo = FakeMarketplaceRepository();
      notifier = MarketplaceNotifier(repository: fakeRepo);
    });

    test('initial state has empty data and no error', () {
      expect(notifier.categories, isEmpty);
      expect(notifier.featuredProducts, isEmpty);
      expect(notifier.popularProducts, isEmpty);
      expect(notifier.isHomeLoading, isFalse);
      expect(notifier.homeError, isNull);
    });

    test('loadHome populates categories, featured, and popular lists', () async {
      await notifier.loadHome();

      expect(notifier.isHomeLoading, isFalse);
      expect(notifier.categories.length, equals(2));
      expect(notifier.featuredProducts.length, equals(2));
      expect(notifier.popularProducts.length, equals(2));
      expect(notifier.homeError, isNull);
    });

    test('loadHome records error message when repo fails', () async {
      fakeRepo.shouldSucceed = false;
      fakeRepo.errorMessage = 'Database connection error';

      await notifier.loadHome(forceRefresh: true);

      expect(notifier.isHomeLoading, isFalse);
      expect(notifier.categories, isEmpty);
      expect(notifier.homeError, equals('Database connection error'));
    });

    test('loadCatalog filters by category', () async {
      await notifier.loadCatalog(categoryId: 'cat-1');

      expect(notifier.catalogProducts.length, equals(1));
      expect(notifier.catalogProducts.first.name, equals('Tecno Camon 30'));
    });

    test('loadCatalog searches products by term', () async {
      await notifier.loadCatalog(search: 'Gara');

      expect(notifier.catalogProducts.length, equals(1));
      expect(notifier.catalogProducts.first.name, equals('Gara Tie Dye Shirt'));
    });

    test('clearFilters resets category, search, and sort criteria', () async {
      notifier.selectCategory('cat-1');
      notifier.setSearchQuery('Tecno');
      notifier.setSortBy('price_asc');

      notifier.clearFilters();

      expect(notifier.selectedCategoryId, isNull);
      expect(notifier.searchQuery, isEmpty);
      expect(notifier.sortBy, equals('newest'));
    });
  });
}
