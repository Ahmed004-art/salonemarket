import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/address_model.dart';

/// Discriminated union result for Address operations.
sealed class AddressResult<T> {
  const AddressResult();
}

final class AddressSuccess<T> extends AddressResult<T> {
  const AddressSuccess(this.value);
  final T value;
}

final class AddressFailure<T> extends AddressResult<T> {
  const AddressFailure(this.message);
  final String message;
}

/// Repository responsible for reading and persisting customer delivery addresses.
class AddressRepository {
  AddressRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient {
    if (_client != null) return _client;
    if (AppConstants.isSupabaseConfigured) {
      return Supabase.instance.client;
    }
    throw StateError('Supabase is not configured.');
  }

  bool get isReady => _client != null || AppConstants.isSupabaseConfigured;

  String? get currentUserId =>
      _client?.auth.currentUser?.id ?? SupabaseService.instance.currentUserId;

  /// Fetches all saved addresses for the current customer.
  Future<AddressResult<List<Address>>> getAddresses() async {
    if (!isReady) {
      return const AddressFailure('Database is not configured.');
    }
    final userId = currentUserId;
    if (userId == null) {
      return const AddressFailure('User is not authenticated.');
    }

    try {
      final List<dynamic> response = await _effectiveClient
          .from('addresses')
          .select()
          .eq('profile_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final addresses = response
          .whereType<Map<String, dynamic>>()
          .map(Address.fromMap)
          .toList();

      return AddressSuccess(addresses);
    } on PostgrestException catch (e) {
      return AddressFailure(e.message);
    } catch (e) {
      return AddressFailure('Failed to load addresses: $e');
    }
  }

  /// Adds a new delivery address for the current customer.
  Future<AddressResult<Address>> addAddress(Address address) async {
    if (!isReady) {
      return const AddressFailure('Database is not configured.');
    }
    final userId = currentUserId;
    if (userId == null) {
      return const AddressFailure('User is not authenticated.');
    }

    try {
      // If setting as default, clear existing defaults first
      if (address.isDefault) {
        await _effectiveClient
            .from('addresses')
            .update({'is_default': false})
            .eq('profile_id', userId);
      }

      final payload = address.copyWith(profileId: userId).toMap(includeId: false);
      final response = await _effectiveClient
          .from('addresses')
          .insert(payload)
          .select()
          .single();

      return AddressSuccess(Address.fromMap(response));
    } on PostgrestException catch (e) {
      return AddressFailure(e.message);
    } catch (e) {
      return AddressFailure('Failed to save address: $e');
    }
  }

  /// Updates an existing delivery address.
  Future<AddressResult<Address>> updateAddress(Address address) async {
    if (!isReady) {
      return const AddressFailure('Database is not configured.');
    }
    final userId = currentUserId;
    if (userId == null) {
      return const AddressFailure('User is not authenticated.');
    }

    try {
      if (address.isDefault) {
        await _effectiveClient
            .from('addresses')
            .update({'is_default': false})
            .eq('profile_id', userId)
            .neq('id', address.id);
      }

      final payload = address.copyWith(profileId: userId).toMap(includeId: false);
      final response = await _effectiveClient
          .from('addresses')
          .update(payload)
          .eq('id', address.id)
          .eq('profile_id', userId)
          .select()
          .single();

      return AddressSuccess(Address.fromMap(response));
    } on PostgrestException catch (e) {
      return AddressFailure(e.message);
    } catch (e) {
      return AddressFailure('Failed to update address: $e');
    }
  }

  /// Deletes an address belonging to the current user.
  Future<AddressResult<void>> deleteAddress(String addressId) async {
    if (!isReady) {
      return const AddressFailure('Database is not configured.');
    }
    final userId = currentUserId;
    if (userId == null) {
      return const AddressFailure('User is not authenticated.');
    }

    try {
      await _effectiveClient
          .from('addresses')
          .delete()
          .eq('id', addressId)
          .eq('profile_id', userId);

      return const AddressSuccess(null);
    } on PostgrestException catch (e) {
      return AddressFailure(e.message);
    } catch (e) {
      return AddressFailure('Failed to delete address: $e');
    }
  }

  /// Marks an address as the customer's default delivery address.
  Future<AddressResult<void>> setDefaultAddress(String addressId) async {
    if (!isReady) {
      return const AddressFailure('Database is not configured.');
    }
    final userId = currentUserId;
    if (userId == null) {
      return const AddressFailure('User is not authenticated.');
    }

    try {
      // 1. Unset all defaults
      await _effectiveClient
          .from('addresses')
          .update({'is_default': false})
          .eq('profile_id', userId);

      // 2. Set new default
      await _effectiveClient
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId)
          .eq('profile_id', userId);

      return const AddressSuccess(null);
    } on PostgrestException catch (e) {
      return AddressFailure(e.message);
    } catch (e) {
      return AddressFailure('Failed to set default address: $e');
    }
  }
}
