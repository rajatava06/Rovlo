import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/backend/backend.dart';
import 'core/config/env.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'services/push_notification_service.dart';

/// Whether Firebase (used only for push notifications) was initialised.
bool firebaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Rovlo is a portrait app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full-screen: draw behind the status and navigation bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Backend first (auth session + database); it is quick and needed to decide
  // which screen to open.
  await Env.load();
  await Backend.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) {
            chat!.bindUser(auth.currentUser?.id, isAgent: auth.isSupportAgent);
            return chat;
          },
        ),
      ],
      child: const RovloApp(),
    ),
  );

  // Firebase is only needed for push notifications — never make the user wait
  // for it.
  unawaited(_initFirebase());
}

Future<void> _initFirebase() async {
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } else if (!kIsWeb) {
      // No FIREBASE_* values were passed: fall back to the native config file
      // (android/app/google-services.json) so push still works when the app is
      // started without --dart-define-from-file.
      await Firebase.initializeApp();
    } else {
      debugPrint('[Rovlo] Firebase keys not found — push notifications disabled.');
      return;
    }
    firebaseInitialized = true;
    await PushNotificationService().initialize();
  } catch (e) {
    firebaseInitialized = false;
    debugPrint('[Rovlo] Firebase initialisation failed: $e');
  }
}
