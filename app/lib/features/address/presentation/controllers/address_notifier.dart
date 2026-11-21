import 'package:flutter/foundation.dart';
import '../../data/models/address_model.dart';
import '../../data/repositories/address_repository.dart';

/// Central state manager for customer delivery address operations.
class AddressNotifier extends ChangeNotifier {
  AddressNotifier({AddressRepository? repository})
      : _repository = repository ?? AddressRepository();

  final AddressRepository _repository;

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isLoading = false;
  String? _errorMessage;

  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Default address if one exists, otherwise first address.
  Address? get defaultAddress {
    if (_addresses.isEmpty) return null;
    return _addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => _addresses.first,
    );
  }

  /// Sets the currently active address for checkout.
  void selectAddress(Address address) {
    _selectedAddress = address;
    notifyListeners();
  }

  /// Loads all addresses from the repository.
  Future<void> loadAddresses({bool preserveSelection = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getAddresses();
    if (result is AddressSuccess<List<Address>>) {
      _addresses = result.value;
      if (!preserveSelection || _selectedAddress == null) {
        _selectedAddress = defaultAddress;
      } else {
        // Keep selected if still in list, else re-evaluate
        final stillExists =
            _addresses.any((a) => a.id == _selectedAddress!.id);
        if (!stillExists) {
          _selectedAddress = defaultAddress;
        } else {
          _selectedAddress =
              _addresses.firstWhere((a) => a.id == _selectedAddress!.id);
        }
      }
      _errorMessage = null;
    } else if (result is AddressFailure<List<Address>>) {
      _errorMessage = result.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new delivery address.
  Future<bool> addAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.addAddress(address);
    if (result is AddressSuccess<Address>) {
      await loadAddresses(preserveSelection: false);
      _selectedAddress = result.value;
      _isLoading = false;
      notifyListeners();
      return true;
    } else if (result is AddressFailure<Address>) {
      _errorMessage = result.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Updates an existing address.
  Future<bool> updateAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.updateAddress(address);
    if (result is AddressSuccess<Address>) {
      await loadAddresses();
      _isLoading = false;
      notifyListeners();
      return true;
    } else if (result is AddressFailure<Address>) {
      _errorMessage = result.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Deletes an address.
  Future<bool> deleteAddress(String addressId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.deleteAddress(addressId);
    if (result is AddressSuccess<void>) {
      await loadAddresses(preserveSelection: false);
      _isLoading = false;
      notifyListeners();
      return true;
    } else if (result is AddressFailure<void>) {
      _errorMessage = result.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Sets an address as the default delivery location.
  Future<bool> setDefaultAddress(String addressId) async {
    final result = await _repository.setDefaultAddress(addressId);
    if (result is AddressSuccess<void>) {
      await loadAddresses();
      return true;
    } else if (result is AddressFailure<void>) {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
    return false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
