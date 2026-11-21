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
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient =>
      _client ?? Supabase.instance.client;

  GoTrueClient get _auth => _effectiveClient.auth;

  // ── Session & User Accessors ──────────────────────────────────────────────

  /// The currently signed-in [User], or `null` if no active session.
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// The active [Session], or `null` if unauthenticated.
  Session? get currentSession {
    try {
      return _auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Whether there is an active authenticated session.
  bool get isAuthenticated => currentUser != null;

  // ── Authentication ───────────────────────────────────────────────────────

  /// Creates a new account with [email] and [password].
  ///
  /// On success the returned value is the Supabase [AuthResponse].
  /// A database trigger automatically creates the `profiles` row.
  Future<AuthResult<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      final metadata = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) {
        metadata['full_name'] = fullName;
      }
      if (phone != null && phone.isNotEmpty) {
        metadata['phone'] = phone;
      }

      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: metadata.isNotEmpty ? metadata : null,
      );
      return AuthSuccess(response);
    } on AuthException catch (e) {
      return AuthFailure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  /// Signs in with [email] and [password].
  Future<AuthResult<AuthResponse>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return AuthSuccess(response);
    } on AuthException catch (e) {
      return AuthFailure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  /// Signs out the current user and clears the session.
  Future<AuthResult<void>> signOut() async {
    try {
      await _auth.signOut();
      return const AuthSuccess(null);
    } on AuthException catch (e) {
      return AuthFailure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  /// Sends a password-reset email to [email].
  Future<AuthResult<void>> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
      return const AuthSuccess(null);
    } on AuthException catch (e) {
      return AuthFailure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  /// Updates the currently signed-in user's password.
  Future<AuthResult<UserResponse>> updatePassword({
    required String newPassword,
  }) async {
    try {
      final response = await _auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return AuthSuccess(response);
    } on AuthException catch (e) {
      return AuthFailure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  /// Fetches the `profiles` row for [userId].
  ///
  /// Returns [AuthFailure] when the row is not found or on network error.
  Future<AuthResult<UserProfile>> getUserProfile(String userId) async {
    try {
      final data = await _effectiveClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return AuthSuccess(UserProfile.fromMap(data));
    } on PostgrestException catch (e) {
      return AuthFailure(e.message);
    } catch (e) {
      return AuthFailure('Unexpected error occurred: $e');
    }
  }

  // ── Auth state stream ────────────────────────────────────────────────────

  /// Emits [AuthState] events whenever the user signs in or out.
  Stream<AuthState> watchAuthState() => _auth.onAuthStateChange;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Converts technical Supabase error strings into friendly user messages.
  static String _mapAuthErrorMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password. Please verify and try again.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already in use')) {
      return 'An account with this email address already exists.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 8 characters long.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return rawMessage;
  }
}
