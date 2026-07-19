import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/app_user.dart';
import 'user_repository.dart';

/// Result of a social sign-in attempt.
class SocialAuthResult {
  const SocialAuthResult(
      {required this.email, required this.name, this.photoUrl});
  final String email;
  final String? name;
  final String? photoUrl;
}

/// Handles authentication for Rovlo.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Google Sign-In uses the native account picker via the `google_sign_in`
/// package. Apple Sign-In remains a demo simulation for now.
///
/// TO CONNECT REAL APPLE AUTH:
///   1. Add `sign_in_with_apple` to pubspec.yaml.
///   2. Replace the body of [signInWithApple] with the real SDK call.
/// ─────────────────────────────────────────────────────────────────────────
class AuthService {
  AuthService(this._users);

  final UserRepository _users;
  final Random _random = Random();

  /// Google Sign-In instance. On Web, it requires the clientId. On Android,
  /// the plugin automatically resolves the OAuth client ID using the app's
  /// registered package name and SHA-1 fingerprint.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '116216537572-1s0gl51bftehu9prmd4i2m8h1p7ff46i.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  static const List<String> _sampleFirstNames = [
    'Alex',
    'Sam',
    'Jordan',
    'Taylor',
    'Riya',
    'Kai',
    'Noor',
    'Leo',
    'Maya',
    'Ivan',
  ];

  // ---------------------------------------------------------------------------
  // Phone
  // ---------------------------------------------------------------------------

  /// Requests an OTP for [phoneNumber]. In demo mode this always "sends" and
  /// the accepted code is `123456`.
  Future<void> requestPhoneOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Real impl: FirebaseAuth.instance.verifyPhoneNumber(...)
  }

  /// Verifies the OTP. Demo mode accepts `123456`.
  Future<bool> verifyPhoneOtp(String phoneNumber, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return code.trim() == '123456';
  }

  // ---------------------------------------------------------------------------
  // Social
  // ---------------------------------------------------------------------------

  /// Triggers the native Google account picker. The user selects one of the
  /// Google accounts already on their device and we get their email, name,
  /// and photo URL back.
  ///
  /// Returns `null` if the user cancels the picker.
  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      // Sign out first to always show the account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker
        return null;
      }

      return SocialAuthResult(
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      // If Google Sign-In fails (e.g. no Play Services), rethrow
      rethrow;
    }
  }

  Future<SocialAuthResult> signInWithApple(
      {String? email, String? name}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (email != null && email.isNotEmpty) {
      return SocialAuthResult(
        email: email,
        name: name ?? email.split('@').first,
      );
    }
    final first = _sampleFirstNames[_random.nextInt(_sampleFirstNames.length)];
    final tag = _random.nextInt(9000) + 1000;
    return SocialAuthResult(
      email: '${first.toLowerCase()}$tag@icloud.com',
      name: first,
    );
  }

  // ---------------------------------------------------------------------------
  // Account resolution
  // ---------------------------------------------------------------------------

  /// Returns an existing account for [email] or creates a fresh one, persisting
  /// it in the repository. Used by both the sign-in and create-account flows.
  Future<AppUser> resolveOrCreate({
    required String email,
    String? name,
    String? phoneNumber,
    required AuthMethod method,
    String? photoUrl,
  }) async {
    final existing = await _users.findByEmail(email);
    if (existing != null) {
      // Merge any new signal (e.g. phone captured before social login).
      final merged = existing.copyWith(
        name: name ?? existing.name,
        phoneNumber: phoneNumber ?? existing.phoneNumber,
        photoUrl: photoUrl ?? existing.photoUrl,
      );
      await _users.upsert(merged);
      return merged;
    }
    final user = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}',
      createdAt: DateTime.now(),
      email: email,
      name: name,
      phoneNumber: phoneNumber,
      authMethod: method,
      photoUrl: photoUrl,
    );
    await _users.upsert(user);
    return user;
  }

  Future<void> updateUser(AppUser user) => _users.upsert(user);
}
