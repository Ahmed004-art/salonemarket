import 'package:supabase_flutter/supabase_flutter.dart';

// ── Result type ────────────────────────────────────────────────────────────

/// A lightweight discriminated-union result type.
///
/// Use [AuthSuccess] for the happy path and [AuthFailure] for errors,
/// so callers never need to catch exceptions from repository methods.
sealed class AuthResult<T> {
  const AuthResult();
}

final class AuthSuccess<T> extends AuthResult<T> {
  const AuthSuccess(this.value);
  final T value;
}

final class AuthFailure<T> extends AuthResult<T> {
  const AuthFailure(this.message);
  final String message;
}

// ── Profile model ──────────────────────────────────────────────────────────

/// Lightweight profile row returned from the `profiles` table.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        role: (map['role'] as String?) ?? 'customer',
        phone: map['phone'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
      );

  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
}

// ── Repository ────────────────────────────────────────────────────────────

/// Data-layer wrapper around Supabase Auth and the `profiles` table.
///
/// All methods return [AuthResult] — callers should handle both
/// [AuthSuccess] and [AuthFailure] without catching exceptions.
class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  // ── Authentication ───────────────────────────────────────────────────────

  /// Creates a new account with [email] and [password].
  ///
  /// On success the returned value is the Supabase [AuthResponse].
  /// A database trigger automatically creates the `profiles` row.
  Future<AuthResult<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );
      return AuthSuccess(response);
    } on AuthException catch (e) {
      return AuthFailure(e.message);
    } catch (e) {
      return AuthFailure('Unexpected error: $e');
    }
  }

  /// Signs in with [email] and [password].
  Future<AuthResult<AuthResponse>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return AuthSuccess(response);
    } on AuthException catch (e) {
      return AuthFailure(e.message);
    } catch (e) {
      return AuthFailure('Unexpected error: $e');
    }
  }

  /// Signs out the current user.
  Future<AuthResult<void>> signOut() async {
    try {
      await _auth.signOut();
      return const AuthSuccess(null);
    } on AuthException catch (e) {
      return AuthFailure(e.message);
    } catch (e) {
      return AuthFailure('Unexpected error: $e');
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  /// Fetches the `profiles` row for [userId].
  ///
  /// Returns [AuthFailure] when the row is not found or on network error.
  Future<AuthResult<UserProfile>> getUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return AuthSuccess(UserProfile.fromMap(data));
    } on PostgrestException catch (e) {
      return AuthFailure(e.message);
    } catch (e) {
      return AuthFailure('Unexpected error: $e');
    }
  }

  // ── Auth state stream ────────────────────────────────────────────────────

  /// Emits [AuthState] events whenever the user signs in or out.
  ///
  /// Subscribe to this in your top-level provider or bloc.
  Stream<AuthState> watchAuthState() => _auth.onAuthStateChange;
}
