import 'package:flutter/foundation.dart' hide Category;

import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';

/// State controller for marketplace browsing, catalog queries, and product search.
class MarketplaceNotifier extends ChangeNotifier {
  MarketplaceNotifier({MarketplaceRepository? repository})
      : _repository = repository ?? MarketplaceRepository();

  final MarketplaceRepository _repository;

  // ── Home screen state ───────────────────────────────────────────────────────
  List<Category> _categories = [];
  List<Product> _featuredProducts = [];
  List<Product> _popularProducts = [];
  bool _isHomeLoading = false;
  String? _homeError;

  List<Category> get categories => _categories;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get popularProducts => _popularProducts;
  bool get isHomeLoading => _isHomeLoading;
  String? get homeError => _homeError;

  // ── Catalog / Search state ─────────────────────────────────────────────────
  List<Product> _catalogProducts = [];
  bool _isCatalogLoading = false;
  String? _catalogError;
  String? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'newest';

  List<Product> get catalogProducts => _catalogProducts;
  bool get isCatalogLoading => _isCatalogLoading;
  String? get catalogError => _catalogError;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Fetches categories, featured and popular products for the home screen.
  Future<void> loadHome({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isNotEmpty && _featuredProducts.isNotEmpty) {
      return;
    }

    _isHomeLoading = true;
    _homeError = null;
    notifyListeners();

    try {
      final catResult = await _repository.getCategories();
      final featResult = await _repository.getFeaturedProducts();
      final popResult = await _repository.getPopularProducts();

      if (catResult is MarketplaceSuccess<List<Category>>) {
        _categories = catResult.value;
      }
      if (featResult is MarketplaceSuccess<List<Product>>) {
        _featuredProducts = featResult.value;
      }
      if (popResult is MarketplaceSuccess<List<Product>>) {
        _popularProducts = popResult.value;
      }

      // Check if any error occurred when all are empty
      if (_categories.isEmpty &&
          _featuredProducts.isEmpty &&
          _popularProducts.isEmpty) {
        if (catResult is MarketplaceFailure) {
          _homeError = (catResult as MarketplaceFailure).message;
        } else if (featResult is MarketplaceFailure) {
          _homeError = (featResult as MarketplaceFailure).message;
        }
      }
    } catch (e) {
      _homeError = 'Failed to load marketplace: $e';
    } finally {
      _isHomeLoading = false;
      notifyListeners();
    }
  }

  /// Loads catalog products with current or supplied filters.
  Future<void> loadCatalog({
    String? categoryId,
    String? search,
    String? sort,
  }) async {
    if (categoryId != null) _selectedCategoryId = categoryId;
    if (search != null) _searchQuery = search;
    if (sort != null) _sortBy = sort;

    _isCatalogLoading = true;
    _catalogError = null;
    notifyListeners();

    try {
      final result = await _repository.getProducts(
        categoryId: _selectedCategoryId,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );

      if (result is MarketplaceSuccess<List<Product>>) {
        _catalogProducts = result.value;
        _catalogError = null;
      } else if (result is MarketplaceFailure<List<Product>>) {
        _catalogError = result.message;
        _catalogProducts = [];
      }
    } catch (e) {
      _catalogError = 'Unable to load products: $e';
      _catalogProducts = [];
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// Changes the active category filter and reloads catalog.
  void selectCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) {
      // Toggle off
      _selectedCategoryId = null;
    } else {
      _selectedCategoryId = categoryId;
    }
    loadCatalog();
  }

  /// Updates the active sort criteria and reloads catalog.
  void setSortBy(String sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    loadCatalog();
  }

  /// Updates search term and reloads catalog.
  void setSearchQuery(String query) {
    _searchQuery = query;
    loadCatalog();
  }

  /// Clears all active filters.
  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = '';
    _sortBy = 'newest';
    loadCatalog();
  }
}
