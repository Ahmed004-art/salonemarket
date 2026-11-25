import 'package:flutter/foundation.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsNotifier extends ChangeNotifier {
  NotificationsNotifier({NotificationsRepository? repository})
      : _repository = repository ?? NotificationsRepository();

  final NotificationsRepository _repository;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final old = _notifications[index];
      _notifications[index] = AppNotification(
        id: old.id,
        userId: old.userId,
        type: old.type,
        title: old.title,
        body: old.body,
        data: old.data,
        isRead: true,
        createdAt: old.createdAt,
      );
      notifyListeners();
      await _repository.markAsRead(id);
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) {
      return AppNotification(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        isRead: true,
        createdAt: n.createdAt,
      );
    }).toList();
    notifyListeners();
    await _repository.markAllAsRead();
  }
}
