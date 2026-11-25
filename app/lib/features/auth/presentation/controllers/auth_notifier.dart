import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../features/cart/presentation/controllers/cart_notifier.dart';
import '../../data/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Central state manager for user authentication and session management.
///
/// Implements [ChangeNotifier] and serves as [Listenable] for [GoRouter]
/// to trigger reactive route guards on sign-in, sign-out, or session expiry.
///
/// Pass a [CartNotifier] via [setCartNotifier] so that sign-in and sign-out
/// automatically scope the cart to the correct user (Finding 3 fix).
class AuthNotifier extends ChangeNotifier {
  AuthNotifier({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _init();
  }

  final AuthRepository _repository;
  CartNotifier? _cartNotifier;

  /// Wire the [CartNotifier] so auth transitions update cart isolation.
  /// Call this once after both notifiers are constructed (see main.dart).
  void setCartNotifier(CartNotifier cartNotifier) {
    _cartNotifier = cartNotifier;
  }

  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserProfile? _profile;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated =>
      (_status == AuthStatus.authenticated && _profile != null) ||
      (_repository.isAuthenticated && _profile != null);
  bool get isCustomer => _profile?.role == Roles.customer;
  bool get isVendor => _profile?.role == Roles.vendor;
  bool get isAdmin => _profile?.role == Roles.admin;

  String? get currentUserId => _repository.currentUser?.id;
  String get userDisplayName =>
      _profile?.fullName.isNotEmpty == true
          ? _profile!.fullName
          : _repository.currentUser?.email ?? 'Shopper';

  // ── Initialization ────────────────────────────────────────────────────────

  void _init() {
    if (!AppConstants.isSupabaseConfigured) {
      _status = AuthStatus.unauthenticated;
      return;
    }

    // Check existing session
    if (_repository.isAuthenticated) {
      _loadProfile(_repository.currentUser!.id);
    } else {
      _status = AuthStatus.unauthenticated;
    }

    // Listen to real-time auth changes
    _authSubscription = _repository.watchAuthState().listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (session?.user != null) {
          _loadProfile(session!.user.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _profile = null;
        _status = AuthStatus.unauthenticated;
        // Clear the cart so the next user (or guest) starts fresh (Finding 3 fix)
        unawaited(_cartNotifier?.clearUser());
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    // Only set loading if we don't already have a profile to avoid blanking
    // screens that are already showing content (e.g. AdminDashboard).
    if (_profile == null) {
      _status = AuthStatus.loading;
      notifyListeners();
    }

    final result = await _repository.getUserProfile(userId);
    if (result is AuthSuccess<UserProfile>) {
      _profile = result.value;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } else if (result is AuthFailure<UserProfile>) {
      // ── Fallback: profile row missing or DB temporarily unavailable ──────
      // CRITICAL: preserve the existing role if we already have a profile
      // loaded (e.g. refresh after a DB hiccup or RLS recursion error).
      // Never downgrade an admin to 'customer' just because one network
      // call failed.
      final existingRole = _profile?.role;

      // Also try to read the role from the Supabase JWT app_metadata / user_metadata
      // so that an admin who opens the app fresh still gets the right role
      // even before the profiles table is accessible.
      final meta = _repository.currentUser?.appMetadata;
      final metaRole = meta?['role'] as String?;

      // Priority: existing role > metadata role > 'customer' (last resort)
      final resolvedRole = existingRole ?? metaRole ?? Roles.customer;

      debugPrint(
        '⚠️ [AuthNotifier._loadProfile] Profile load failed: ${(result as AuthFailure).message}\n'
        '   Preserving role: $resolvedRole (existing=$existingRole, meta=$metaRole)',
      );

      _profile = UserProfile(
        id: userId,
        fullName: _profile?.fullName ?? _repository.currentUser?.userMetadata?['full_name'] as String? ?? '',
        role: resolvedRole,
        phone: _profile?.phone,
        avatarUrl: _profile?.avatarUrl,
      );
      _status = AuthStatus.authenticated;
    }

    // Scope the cart to the authenticated user (Finding 3 fix)
    await _cartNotifier?.setUser(userId);

    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Signs in an existing customer or vendor.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.signInWithEmail(
      email: email,
      password: password,
    );

    if (result is AuthSuccess<AuthResponse>) {
      final user = result.value.user;
      if (user != null) {
        await _loadProfile(user.id);
        return true;
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else if (result is AuthFailure<AuthResponse>) {
      _errorMessage = result.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    return false;
  }

  /// Registers a new customer account.
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );

    if (result is AuthSuccess<AuthResponse>) {
      final user = result.value.user;
      final session = result.value.session;

      if (session != null && user != null) {
        await _loadProfile(user.id);
      } else {
        // Needs email verification
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
      return true;
    } else if (result is AuthFailure<AuthResponse>) {
      _errorMessage = result.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    return false;
  }

  /// Sends a password recovery email.
  Future<bool> sendPasswordReset({required String email}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.resetPasswordForEmail(email: email);

    if (result is AuthSuccess<void>) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } else if (result is AuthFailure<void>) {
      _errorMessage = result.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    return false;
  }

  /// Updates the password for the current session.
  Future<bool> updatePassword({required String newPassword}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.updatePassword(newPassword: newPassword);

    if (result is AuthSuccess<UserResponse>) {
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else if (result is AuthFailure<UserResponse>) {
      _errorMessage = result.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    return false;
  }

  /// Updates profile details (e.g. full name, phone number, avatar URL) for the signed-in user.
  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final current = _profile;
    if (current == null) return false;

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.updateUserProfile(
      userId: current.id,
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
    );

    if (result is AuthSuccess<UserProfile>) {
      _profile = result.value;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else if (result is AuthFailure<UserProfile>) {
      _errorMessage = result.message;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
    return false;
  }

  /// Uploads avatar image bytes to the storage bucket and returns the public URL.
  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final current = _profile;
    if (current == null) return null;
    return await _repository.uploadAvatar(
      userId: current.id,
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }

  /// Signs the user out.
  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Isolate the cart before destroying the session (Finding 3 fix)
    await _cartNotifier?.clearUser();

    await _repository.signOut();
    _profile = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Force-reloads the profile from Supabase.
  ///
  /// Call this from screens that require up-to-date role information
  /// (e.g. AdminDashboardScreen) to correct a stale fallback role that
  /// may have been set when the initial profile load failed due to a
  /// network or database error.
  Future<void> refreshProfile() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _loadProfile(userId);
  }

  /// Clears active error messages.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
