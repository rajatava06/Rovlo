import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'services/push_notification_service.dart';

/// Whether Firebase was successfully initialized.
/// AuthProvider checks this to decide whether to use Firebase Auth or fallback.
bool firebaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Rovlo supports portrait usage; lock orientation for a consistent feel.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Initialize Firebase (only when secrets are injected via .env) ─────────
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      debugPrint('[Rovlo] Firebase initialized successfully.');

      // Initialize Push Notification Service (FCM)
      await PushNotificationService().initialize();
    } catch (e) {
      firebaseInitialized = false;
      debugPrint('[Rovlo] Firebase initialization failed: $e');
    }
  } else {
    firebaseInitialized = false;
    debugPrint('[Rovlo] Firebase secrets not found — run with --dart-define-from-file=.env');
  }
  // ─────────────────────────────────────────────────────────────────────────

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const RovloApp(),
    ),
  );
}
