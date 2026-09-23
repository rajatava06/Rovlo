import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../main.dart' show firebaseInitialized;
import 'user_repository.dart';

/// Firebase Cloud Messaging: asks for permission, obtains the device token and
/// stores it on the signed-in user's profile so the `send-push` Edge Function
/// can reach the device.
class PushNotificationService {
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  FirebaseMessaging? get _messaging =>
      firebaseInitialized ? FirebaseMessaging.instance : null;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialised = false;
  String? _userId;
  final UserRepository _users = UserRepository();

  /// Requests permission and fetches the token (call once at start-up).
  Future<void> initialize() async {
    final messaging = _messaging;
    if (messaging == null || _initialised) return;
    _initialised = true;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      _fcmToken = await messaging.getToken();
      messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _save();
      });
      await _save();
    } catch (e) {
      debugPrint('[PushNotificationService] init failed: $e');
    }
  }

  /// Links this device's token to the signed-in user.
  Future<void> bindUser(String userId) async {
    _userId = userId;
    await _save();
  }

  Future<void> _save() async {
    final id = _userId;
    final token = _fcmToken;
    if (id == null || token == null || token.isEmpty) return;
    try {
      await _users.setFcmToken(id, token);
    } catch (e) {
      debugPrint('[PushNotificationService] could not save token: $e');
    }
  }

  /// Removes the token from the profile so a signed-out device gets no pushes.
  Future<void> unbindCurrentUser() async {
    final id = _userId;
    _userId = null;
    if (id == null) return;
    try {
      await _users.setFcmToken(id, null);
    } catch (_) {}
  }
}
