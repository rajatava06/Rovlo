import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_notification.dart';

class NotificationService {
  static const String _notificationsKey = 'rovlo_admin_notifications';
  
  final StreamController<AdminNotification> _broadcastController =
      StreamController<AdminNotification>.broadcast();

  Stream<AdminNotification> get onNotification => _broadcastController.stream;

  Future<List<AdminNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_notificationsKey) ?? [];
    final notifications = rawList
        .map((item) {
          try {
            return AdminNotification.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<AdminNotification>()
        .toList();
    notifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return notifications;
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.announcement,
    String targetAudience = 'All Users',
    String sentBy = 'Admin',
  }) async {
    final notification = AdminNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      sentAt: DateTime.now(),
      type: type,
      targetAudience: targetAudience,
      sentBy: sentBy,
    );

    final current = await getNotifications();
    current.insert(0, notification);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notificationsKey,
      current.map((n) => n.toJson()).toList(),
    );

    _broadcastController.add(notification);
  }

  Future<void> deleteNotification(String id) async {
    final current = await getNotifications();
    current.removeWhere((n) => n.id == id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notificationsKey,
      current.map((n) => n.toJson()).toList(),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }
}
