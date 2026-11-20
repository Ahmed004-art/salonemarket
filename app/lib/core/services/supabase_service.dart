import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin singleton wrapper around [SupabaseClient].
///
/// Provides typed accessors for the most common operations.
///
/// ⚠️  SECURITY: The Supabase service-role key MUST NEVER appear in this file
/// or anywhere else in the client-side Dart/Flutter code. Use only the
/// anon key (injected via --dart-define at build time). Service-role
/// operations belong exclusively in Supabase Edge Functions running
/// server-side.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  /// The underlying [SupabaseClient]. Prefer the typed helpers below.
  SupabaseClient get client => Supabase.instance.client;

  /// Shorthand for [client.auth].
  GoTrueClient get auth => client.auth;

  /// The currently signed-in [User], or `null` if no active session.
  User? get currentUser => auth.currentUser;

  /// The UUID of the currently signed-in user, or `null`.
  String? get currentUserId => currentUser?.id;

  /// Whether there is an active session.
  bool get isAuthenticated => currentUser != null;

  /// Signs the current user out and clears the local session.
  Future<void> signOut() async {
    await auth.signOut();
  }
}
