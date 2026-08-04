import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show firebaseInitialized;

/// Handles FCM Push Notifications (Foreground, Background, Token Registration)
class PushNotificationService {
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  static final PushNotificationService _instance = PushNotificationService._internal();

  FirebaseMessaging? get _messaging => firebaseInitialized ? FirebaseMessaging.instance : null;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const String _backendApiUrl = 'http://localhost:5000/api/notifications/register-token';

  /// Initialize FCM Push Notifications
  Future<void> initialize() async {
    if (!firebaseInitialized || _messaging == null) {
      debugPrint('[PushNotificationService] Firebase not initialized — running in local fallback mode.');
      return;
    }

    try {
      // 1. Request notification permissions (iOS & Android 13+)
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[PushNotificationService] User granted permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Fetch FCM Token
        _fcmToken = await _messaging!.getToken();
        debugPrint('[PushNotificationService] FCM Token: $_fcmToken');

        // 3. Listen for token refresh
        _messaging!.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('[PushNotificationService] FCM Token refreshed: $newToken');
        });

        // 4. Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[PushNotificationService] Foreground Message received: ${message.notification?.title}');
          debugPrint('Body: ${message.notification?.body}');
        });

        // 5. Handle Notification Taps (App opened from notification)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('[PushNotificationService] App opened from notification: ${message.notification?.title}');
        });
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error initializing push notifications: $e');
    }
  }

  /// Register FCM Token with Rovlo-Backend server
  Future<bool> registerTokenWithBackend(String userId) async {
    if (_fcmToken == null || _fcmToken!.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_backendApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'fcmToken': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[PushNotificationService] Token successfully registered with Rovlo-Backend.');
        return true;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Backend registration failed: $e');
    }
    return false;
  }
}
