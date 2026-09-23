import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/admin_notification.dart';

/// Admin broadcasts, stored in `public.broadcasts`.
///
/// * Everyone can read them and receives new ones live (Supabase Realtime)
///   while the app is open — shown as an in-app banner.
/// * Admins can send / delete. Sending also triggers the `send-push` Edge
///   Function so devices with the app closed get a real push (FCM).
class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._();
  static final NotificationService _instance = NotificationService._();

  final StreamController<AdminNotification> _controller =
      StreamController<AdminNotification>.broadcast();
  RealtimeChannel? _channel;

  Stream<AdminNotification> get onNotification => _controller.stream;

  SupabaseClient get _db => Backend.client;

  /// Starts listening for new broadcasts (idempotent).
  void start() {
    if (_channel != null || !Backend.ready) return;
    _channel = _db
        .channel('rovlo-broadcasts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'broadcasts',
          callback: (payload) {
            try {
              _controller.add(AdminNotification.fromRow(payload.newRecord));
            } catch (e) {
              debugPrint('[NotificationService] bad payload: $e');
            }
          },
        )
        .subscribe();
  }

  Future<void> stop() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) await _db.removeChannel(ch);
  }

  Future<List<AdminNotification>> getNotifications({int limit = 50}) async {
    final rows = await _db
        .from('broadcasts')
        .select()
        .order('sent_at', ascending: false)
        .limit(limit);
    return rows.map<AdminNotification>(AdminNotification.fromRow).toList();
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.announcement,
    String targetAudience = 'All Users',
    String sentBy = 'Admin',
  }) async {
    await _db.from('broadcasts').insert({
      'title': title,
      'body': body,
      'type': type.name,
      'target_audience': targetAudience,
      'sent_by': sentBy,
    });

    // Real push to devices. Best effort: the in-app broadcast already exists.
    try {
      await _db.functions.invoke('send-push', body: {
        'title': title,
        'body': body,
        'target': targetAudience,
      });
    } catch (e) {
      debugPrint('[NotificationService] push not sent: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    await _db.from('broadcasts').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    await _db
        .from('broadcasts')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
  }
}
