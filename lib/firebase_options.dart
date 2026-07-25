// Firebase configuration for Rovlo.
// Project: ai-studio-applet-webapp-1b0fc
// Generated from Firebase Console values.

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
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA5I57hoaGEori0e_iaw2yQFabw1bZC0Oo',
    appId: '1:593111392034:web:1f9f81ae90cfc404e64f7b',
    messagingSenderId: '593111392034',
    projectId: 'ai-studio-applet-webapp-1b0fc',
    authDomain: 'ai-studio-applet-webapp-1b0fc.firebaseapp.com',
    storageBucket: 'ai-studio-applet-webapp-1b0fc.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5I57hoaGEori0e_iaw2yQFabw1bZC0Oo',
    appId: '1:593111392034:android:0d6e82151473182de64f7b',
    messagingSenderId: '593111392034',
    projectId: 'ai-studio-applet-webapp-1b0fc',
    storageBucket: 'ai-studio-applet-webapp-1b0fc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA5I57hoaGEori0e_iaw2yQFabw1bZC0Oo',
    appId: '1:593111392034:ios:d54e1519a5872c8be64f7b',
    messagingSenderId: '593111392034',
    projectId: 'ai-studio-applet-webapp-1b0fc',
    storageBucket: 'ai-studio-applet-webapp-1b0fc.firebasestorage.app',
    iosBundleId: 'com.example.rovlo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA5I57hoaGEori0e_iaw2yQFabw1bZC0Oo',
    appId: '1:593111392034:ios:d54e1519a5872c8be64f7b',
    messagingSenderId: '593111392034',
    projectId: 'ai-studio-applet-webapp-1b0fc',
    storageBucket: 'ai-studio-applet-webapp-1b0fc.firebasestorage.app',
    iosBundleId: 'com.example.rovlo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA5I57hoaGEori0e_iaw2yQFabw1bZC0Oo',
    appId: '1:593111392034:web:1252292c4cbcf639e64f7b',
    messagingSenderId: '593111392034',
    projectId: 'ai-studio-applet-webapp-1b0fc',
    authDomain: 'ai-studio-applet-webapp-1b0fc.firebaseapp.com',
    storageBucket: 'ai-studio-applet-webapp-1b0fc.firebasestorage.app',
  );
}
