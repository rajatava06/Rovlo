// Firebase configuration for Rovlo.
// Secrets are injected at build time using --dart-define-from-file=.env
// Do NOT hardcode any API keys here — this file is committed to git.
//
// ─────────────────────────────────────────────────────────────────────────────
// HOW TO RUN / BUILD:
//   flutter run --dart-define-from-file=.env
//   flutter build apk --release --dart-define-from-file=.env
//   flutter build appbundle --release --dart-define-from-file=.env
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Values are injected via --dart-define-from-file=.env at build time.
// They fall back to empty strings so the app compiles without a .env file
// (Firebase will not be initialized in that case — handled in main.dart).
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const _windowsAppId = String.fromEnvironment('FIREBASE_WINDOWS_APP_ID');
const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

class DefaultFirebaseOptions {
  /// Whether secrets have been injected via --dart-define-from-file.
  static bool get isConfigured => _apiKey.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _apiKey,
        appId: _webAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain,
        storageBucket: _storageBucket,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _apiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: 'com.example.rovlo',
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: 'com.example.rovlo',
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _apiKey,
        appId: _windowsAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain,
        storageBucket: _storageBucket,
      );
}
