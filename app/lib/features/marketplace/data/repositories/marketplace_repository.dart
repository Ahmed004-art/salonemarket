import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

/// Discriminated union result type for marketplace queries.
sealed class MarketplaceResult<T> {
  const MarketplaceResult();
}

final class MarketplaceSuccess<T> extends MarketplaceResult<T> {
  const MarketplaceSuccess(this.value);
  final T value;
}

final class MarketplaceFailure<T> extends MarketplaceResult<T> {
  const MarketplaceFailure(this.message);
  final String message;
}

/// Repository responsible for reading active marketplace data from Supabase.
class MarketplaceRepository {
  MarketplaceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient {
    if (_client != null) return _client;
    if (AppConstants.isSupabaseConfigured) {
      return Supabase.instance.client;
    }
    throw StateError('Supabase is not configured.');
  }

  bool get isReady =>
      _client != null || AppConstants.isSupabaseConfigured;

  /// Fetches published taxonomy categories.
  Future<MarketplaceResult<List<Category>>> getCategories({
    bool topLevelOnly = true,
  }) async {
    if (!isReady) {
      return const MarketplaceFailure('Database is not configured.');
    }

    try {
      PostgrestFilterBuilder<PostgrestList> filter = _effectiveClient
          .from('categories')
          .select()
          .eq('is_active', true);

      if (topLevelOnly) {
        filter = filter.filter('parent_id', 'is', 'null');
      }

      final List<dynamic> response =
          await filter.order('sort_order', ascending: true);
      final categories = response
          .whereType<Map<String, dynamic>>()
          .map(Category.fromMap)
          .toList();

      return MarketplaceSuccess(categories);
    } on PostgrestException catch (e) {
      return MarketplaceFailure(e.message);
    } catch (e) {
      return MarketplaceFailure('Unable to load categories: $e');
    }
  }

  /// Fetches featured products for the home screen (active products with highest rating).
  Future<MarketplaceResult<List<Product>>> getFeaturedProducts({
    int limit = 8,
  }) async {
    if (!isReady) {
      return const MarketplaceFailure('Database is not configured.');
    }

    try {
      final List<dynamic> response = await _effectiveClient
          .from('products')
          .select('''
            *,
            vendors:vendor_id!inner (id, shop_name, slug, location, status, rating_avg, rating_count),
            categories:category_id (name, slug),
            product_images (id, url, alt_text, sort_order, is_primary)
          ''')
          .eq('status', 'active')
          .eq('vendors.status', 'active')
          .order('rating_avg', ascending: false)
          .limit(limit);

      final products = response
          .whereType<Map<String, dynamic>>()
          .map(Product.fromMap)
          .where((p) => p.status == 'active' && p.vendor != null && p.vendor!.status == 'active')
          .toList();

      return MarketplaceSuccess(products);
    } on PostgrestException catch (e) {
      return MarketplaceFailure(e.message);
    } catch (e) {
      return MarketplaceFailure('Unable to load featured products: $e');
    }
  }

  /// Fetches popular / trending products (active products with highest rating count).
  Future<MarketplaceResult<List<Product>>> getPopularProducts({
    int limit = 8,
  }) async {
    if (!isReady) {
      return const MarketplaceFailure('Database is not configured.');
    }

    try {
      final List<dynamic> response = await _effectiveClient
          .from('products')
          .select('''
            *,
            vendors:vendor_id!inner (id, shop_name, slug, location, status, rating_avg, rating_count),
            categories:category_id (name, slug),
            product_images (id, url, alt_text, sort_order, is_primary)
          ''')
          .eq('status', 'active')
          .eq('vendors.status', 'active')
          .order('rating_count', ascending: false)
          .limit(limit);

      final products = response
          .whereType<Map<String, dynamic>>()
          .map(Product.fromMap)
          .where((p) => p.status == 'active' && p.vendor != null && p.vendor!.status == 'active')
          .toList();

      return MarketplaceSuccess(products);
    } on PostgrestException catch (e) {
      return MarketplaceFailure(e.message);
    } catch (e) {
      return MarketplaceFailure('Unable to load popular products: $e');
    }
  }

  /// Queries product catalog with optional filtering, search, sorting, and pagination.
  Future<MarketplaceResult<List<Product>>> getProducts({
    String? categoryId,
    String? searchQuery,
    String sortBy = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    if (!isReady) {
      return const MarketplaceFailure('Database is not configured.');
    }

    try {
      PostgrestFilterBuilder<PostgrestList> filter = _effectiveClient
          .from('products')
          .select('''
            *,
            vendors:vendor_id!inner (id, shop_name, slug, location, status, rating_avg, rating_count),
            categories:category_id (name, slug),
            product_images (id, url, alt_text, sort_order, is_primary)
          ''')
          .eq('status', 'active')
          .eq('vendors.status', 'active');

      if (categoryId != null && categoryId.isNotEmpty) {
        filter = filter.eq('category_id', categoryId);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        filter = filter.ilike('name', term);
      }

      PostgrestTransformBuilder<PostgrestList> transform;
      switch (sortBy) {
        case 'price_asc':
          transform = filter.order('price', ascending: true);
          break;
        case 'price_desc':
          transform = filter.order('price', ascending: false);
          break;
        case 'rating':
          transform = filter.order('rating_avg', ascending: false);
          break;
        case 'popular':
          transform = filter.order('rating_count', ascending: false);
          break;
        case 'newest':
        default:
          transform = filter.order('created_at', ascending: false);
          break;
      }

      final List<dynamic> response =
          await transform.range(offset, offset + limit - 1);
      final products = response
          .whereType<Map<String, dynamic>>()
          .map(Product.fromMap)
          .where((p) => p.status == 'active' && p.vendor != null && p.vendor!.status == 'active')
          .toList();

      return MarketplaceSuccess(products);
    } on PostgrestException catch (e) {
      return MarketplaceFailure(e.message);
    } catch (e) {
      return MarketplaceFailure('Unable to load catalog: $e');
    }
  }

  /// Fetches a single active product with all related images and merchant store info.
  Future<MarketplaceResult<Product>> getProductById(String id) async {
    if (!isReady) {
      return const MarketplaceFailure('Database is not configured.');
    }

    try {
      final response = await _effectiveClient
          .from('products')
          .select('''
            *,
            vendors:vendor_id!inner (id, profile_id, shop_name, slug, description, logo_url, cover_image_url, location, phone, email, status, rating_avg, rating_count, commission_rate),
            categories:category_id (name, slug),
            product_images (id, product_id, url, alt_text, sort_order, is_primary)
          ''')
          .eq('id', id)
          .eq('status', 'active')
          .eq('vendors.status', 'active')
          .single();

      final product = Product.fromMap(response);
      if (product.status != 'active' || product.vendor == null || product.vendor!.status != 'active') {
        return const MarketplaceFailure('This product is currently unavailable.');
      }

      return MarketplaceSuccess(product);
    } on PostgrestException catch (e) {
      return MarketplaceFailure(e.message);
    } catch (e) {
      return MarketplaceFailure('Unable to load product details: $e');
    }
  }
}
