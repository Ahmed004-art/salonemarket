import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/notification_model.dart';

/// Repository for customer in-app notifications.
class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client}) : _client = client;

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

  /// Fetches notifications for the current user.
  Future<List<AppNotification>> getNotifications() async {
    if (!isReady) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await _effectiveClient
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list
          .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Marks a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    if (!isReady) return;
    try {
      await _effectiveClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  /// Marks all notifications for the current user as read via RPC.
  Future<void> markAllAsRead() async {
    if (!isReady) return;
    try {
      await _effectiveClient.rpc('mark_all_notifications_read');
    } catch (_) {}
  }
}
