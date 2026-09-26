import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show firebaseInitialized;
import 'app_navigation.dart';
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

  static const String _prefsKey = 'rovlo_push_enabled';

  bool _initialised = false;
  bool _listening = false;
  bool _openHandlersWired = false;
  bool _enabled = true;
  String? _userId;
  final UserRepository _users = UserRepository();

  /// Whether the user wants push notifications on this device (Settings →
  /// Notifications). Defaults to on.
  bool get enabled => _enabled;

  /// Reads the saved on/off choice. Safe to call any time.
  Future<bool> loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {}
    return _enabled;
  }

  /// Requests permission and fetches the token (call once at start-up).
  /// Does nothing when the user switched notifications off.
  Future<void> initialize() async {
    final messaging = _messaging;
    await loadPreference();
    if (messaging != null) await _wireOpenHandlers(messaging);
    if (messaging == null || _initialised || !_enabled) return;
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
      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          _save();
        });
      }
      await _save();
    } catch (e) {
      debugPrint('[PushNotificationService] init failed: $e');
    }
  }

  /// Tapping a chat notification (app in the background or closed) opens the
  /// Chats tab.
  Future<void> _wireOpenHandlers(FirebaseMessaging messaging) async {
    if (_openHandlersWired) return;
    _openHandlersWired = true;
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onNotificationOpened(initial);
    } catch (e) {
      debugPrint('[PushNotificationService] open handlers failed: $e');
    }
  }

  void _onNotificationOpened(RemoteMessage message) {
    final type = message.data['type'];
    if (type is String && type.startsWith('chat_')) AppNavigation.openChats();
  }

  /// Links this device's token to the signed-in user.
  Future<void> bindUser(String userId) async {
    _userId = userId;
    await _save();
  }

  /// Turns push notifications on/off for this device. Off = the server has no
  /// device token for me, so nothing is ever sent (the in-app bell still works).
  /// Returns false when it could not be applied — e.g. the phone's own
  /// notification permission is blocked, or there is no connection.
  Future<bool> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      _enabled = true;
      _initialised = false;
      await initialize();
      final token = _fcmToken;
      if (token == null || token.isEmpty) {
        _enabled = false; // permission denied / no Firebase
        return false;
      }
      await prefs.setBool(_prefsKey, true);
      return true;
    }
    try {
      final id = _userId;
      if (id != null) await _users.setFcmToken(id, null);
    } catch (e) {
      debugPrint('[PushNotificationService] could not switch off: $e');
      return false;
    }
    _enabled = false;
    await prefs.setBool(_prefsKey, false);
    return true;
  }

  Future<void> _save() async {
    if (!_enabled) return;
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
