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

  // ── Initialize Firebase (graceful — app works without it) ──────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('[Rovlo] Firebase initialized successfully.');
  } catch (e) {
    firebaseInitialized = false;
    debugPrint('[Rovlo] Firebase initialization failed: $e');
    debugPrint('[Rovlo] App will continue without Firebase Auth.');
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
