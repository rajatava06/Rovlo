import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/app_user.dart';
import 'user_repository.dart';

/// Result of a social sign-in attempt.
class SocialAuthResult {
  const SocialAuthResult({
    required this.email,
    required this.name,
    this.photoUrl,
    this.firebaseUid,
  });
  final String email;
  final String? name;
  final String? photoUrl;
  final String? firebaseUid;
}

/// Handles authentication for Rovlo using Firebase Auth.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Google Sign-In: Uses `google_sign_in` to get idToken/accessToken, then
///   signs into Firebase with GoogleAuthProvider.credential().
///
/// Apple Sign-In: Uses `sign_in_with_apple` to get identityToken, then
///   signs into Firebase with OAuthProvider('apple.com').credential().
///
/// Persistent Session: Firebase Auth automatically persists the user's
///   authentication state. On app restart, `FirebaseAuth.instance.currentUser`
///   returns the signed-in user without re-authentication.
/// ─────────────────────────────────────────────────────────────────────────
class AuthService {
  AuthService(this._users);

  final UserRepository _users;
  final Random _random = Random();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static const String _webClientId =
      '593111392034-iiukhf2sj66e6kos1i2fkpmsdmjc5mp5.apps.googleusercontent.com';

  /// Google Sign-In instance. On Web, it requires clientId. On Android,
  /// serverClientId ensures Google issues an idToken compatible with Firebase Auth.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  /// Returns the currently signed-in Firebase user, or null.
  User? get firebaseCurrentUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes (sign-in / sign-out events).
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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
  // Google Sign-In (Firebase Auth)
  // ---------------------------------------------------------------------------

  /// Triggers the native Google account picker, obtains idToken + accessToken,
  /// then signs into Firebase with GoogleAuthProvider.credential().
  ///
  /// Returns `null` if the user cancels the picker.
  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      // Clear previous cached session so native device account picker is always shown
      await _googleSignIn.signOut().catchError((_) => null);

      // Open native device Google Account picker
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled or closed the device account picker
        return null;
      }

      // Obtain the auth details from the Google Sign-In
      final GoogleSignInAuthentication googleAuth =
          await account.authentication;

      // Create a Firebase credential from the Google tokens
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      return SocialAuthResult(
        email: firebaseUser.email ?? account.email,
        name: firebaseUser.displayName ??
            account.displayName ??
            account.email.split('@').first,
        photoUrl: firebaseUser.photoURL ??
            account.photoUrl ??
            'https://api.dicebear.com/7.x/avataaars/png?seed=${account.email}',
        firebaseUid: firebaseUser.uid,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In (Firebase Auth)
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically secure random nonce for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the SHA-256 hash of [input].
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Triggers native Apple Sign-In, then signs into Firebase with the
  /// Apple credential.
  ///
  /// Returns `null` if the user cancels.
  Future<SocialAuthResult?> signInWithApple() async {
    try {
      // Generate a nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple Sign-In credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create an OAuthCredential for Firebase
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(oauthCredential);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      // Apple only sends name on first sign-in; use Firebase's cached version
      final String? displayName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
              .trim()
          : firebaseUser.displayName;

      return SocialAuthResult(
        email: firebaseUser.email ??
            appleCredential.email ??
            '${firebaseUser.uid}@privaterelay.appleid.com',
        name: displayName ?? firebaseUser.email?.split('@').first,
        photoUrl: firebaseUser.photoURL,
        firebaseUid: firebaseUser.uid,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null; // User cancelled
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  /// Signs out from Firebase and Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) => null);
    await _firebaseAuth.signOut();
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
    String? firebaseUid,
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
      id: firebaseUid ??
          'usr_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}',
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
