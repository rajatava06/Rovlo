import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/backend/backend.dart';
import '../core/config/env.dart';
import '../models/app_user.dart';
import 'user_repository.dart';

/// Result of a social sign-in attempt.
class SocialAuthResult {
  const SocialAuthResult({
    required this.userId,
    required this.email,
    required this.name,
    this.photoUrl,
  });
  final String userId;
  final String? email;
  final String? name;
  final String? photoUrl;
}

/// Authentication through Supabase Auth.
///
/// Google: the native account picker (`google_sign_in`) returns an ID token
///   which is exchanged for a Supabase session with `signInWithIdToken`.
/// Apple: same idea with `sign_in_with_apple` + a hashed nonce.
/// Sessions are stored and refreshed automatically by `supabase_flutter`, so
///   users stay signed in across app restarts.
class AuthService {
  AuthService(this._users);

  final UserRepository _users;

  sb.SupabaseClient get _sb => Backend.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? Env.googleWebClientId : null,
    serverClientId: Env.googleWebClientId,
    scopes: const ['email', 'profile'],
  );

  sb.User? get currentAuthUser => Backend.ready ? _sb.auth.currentUser : null;

  Stream<sb.AuthState> get authStateChanges =>
      Backend.ready ? _sb.auth.onAuthStateChange : const Stream<sb.AuthState>.empty();

  // ---------------------------------------------------------------------------
  // Phone (verification UI only — see README: wire an SMS provider before launch)
  // ---------------------------------------------------------------------------

  /// Requests an OTP for [phoneNumber]. Demo mode: accepted code is `123456`.
  Future<void> requestPhoneOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
  }

  Future<bool> verifyPhoneOtp(String phoneNumber, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return code.trim() == '123456';
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  /// Returns `null` if the user closes the account picker.
  Future<SocialAuthResult?> signInWithGoogle() async {
    // Forget the previous account so the picker always appears.
    await _googleSignIn.signOut().catchError((_) => null);

    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const sb.AuthException(
        'Google did not return an ID token. Check GOOGLE_WEB_CLIENT_ID and the '
        'Android SHA-1 fingerprint in Google Cloud.',
      );
    }

    final res = await _sb.auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    final user = res.user;
    if (user == null) return null;

    return SocialAuthResult(
      userId: user.id,
      email: user.email ?? account.email,
      name: account.displayName ?? account.email.split('@').first,
      photoUrl: account.photoUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Apple
  // ---------------------------------------------------------------------------

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Returns `null` if the user cancels.
  Future<SocialAuthResult?> signInWithApple() async {
    final rawNonce = _generateNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256ofString(rawNonce),
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const sb.AuthException('Apple did not return an identity token.');
      }

      final res = await _sb.auth.signInWithIdToken(
        provider: sb.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      final user = res.user;
      if (user == null) return null;

      // Apple only sends the name on the very first sign-in.
      final fullName = [credential.givenName, credential.familyName]
          .whereType<String>()
          .join(' ')
          .trim();

      return SocialAuthResult(
        userId: user.id,
        email: user.email ?? credential.email,
        name: fullName.isNotEmpty ? fullName : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Debug-only guest account (needs "Anonymous sign-ins" enabled in Supabase)
  // ---------------------------------------------------------------------------

  Future<SocialAuthResult?> signInAnonymously() async {
    final res = await _sb.auth.signInAnonymously();
    final user = res.user;
    if (user == null) return null;
    return SocialAuthResult(
      userId: user.id,
      email: null,
      name: 'Demo Traveler',
      photoUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Demo',
    );
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) => null);
    if (Backend.ready) await _sb.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Profile resolution
  // ---------------------------------------------------------------------------

  /// Returns the profile row of the signed-in user. The row is normally created
  /// by a database trigger the moment the account is created; if it is missing
  /// (very rare) it is created here. Missing fields are filled from the social
  /// account, but details the user already edited are never overwritten.
  Future<AppUser> resolveProfile({
    required String userId,
    String? email,
    String? name,
    String? phoneNumber,
    required AuthMethod method,
    String? photoUrl,
  }) async {
    final existing = await _users.findById(userId);
    if (existing != null) {
      final hasName = existing.name != null && existing.name!.trim().isNotEmpty;
      final hasPhoto = existing.photoUrl != null && existing.photoUrl!.isNotEmpty;
      final merged = existing.copyWith(
        name: hasName ? null : name,
        phoneNumber: phoneNumber,
        photoUrl: hasPhoto ? null : photoUrl,
        email: (existing.email == null || existing.email!.isEmpty) ? email : null,
      );
      final changed = merged.name != existing.name ||
          merged.phoneNumber != existing.phoneNumber ||
          merged.photoUrl != existing.photoUrl ||
          merged.email != existing.email;
      if (changed) await _users.upsert(merged);
      return merged;
    }

    final user = AppUser(
      id: userId,
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

  /// Deletes the signed-in account and all its data (database function).
  Future<void> deleteMyAccount() async {
    await _sb.rpc('delete_my_account');
    await signOut();
  }
}
