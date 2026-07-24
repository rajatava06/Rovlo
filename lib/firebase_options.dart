// File generated manually — replace with `flutterfire configure` output.
// See: https://firebase.google.com/docs/flutter/setup
//
// ─────────────────────────────────────────────────────────────────────────────
// HOW TO REGENERATE:
//   1. Run `firebase login` in your terminal (interactive).
//   2. Run `flutterfire configure` in the project root.
//   3. This file will be overwritten with the correct values.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return web; // fallback for desktop dev
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REPLACE the values below with the output of `flutterfire configure`.
  // The placeholder values below will NOT work — they are just structural
  // scaffolding so the app compiles.
  // ──────────────────────────────────────────────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rovlo-app',
    authDomain: 'rovlo-app.firebaseapp.com',
    storageBucket: 'rovlo-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rovlo-app',
    storageBucket: 'rovlo-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rovlo-app',
    storageBucket: 'rovlo-app.firebasestorage.app',
    iosBundleId: 'com.example.rovlo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rovlo-app',
    storageBucket: 'rovlo-app.firebasestorage.app',
    iosBundleId: 'com.example.rovlo',
  );
}
