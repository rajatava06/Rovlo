import 'dart:math';

import '../models/app_user.dart';
import 'user_repository.dart';

/// Result of a social sign-in attempt.
class SocialAuthResult {
  const SocialAuthResult({required this.email, required this.name, this.photoUrl});
  final String email;
  final String? name;
  final String? photoUrl;
}

/// Handles authentication for Rovlo.
///
/// ─────────────────────────────────────────────────────────────────────────
/// DEMO MODE (default): the Google / Apple flows below are fully functional
/// simulations so the app runs and is launchable with zero backend setup.
/// They return a realistic account after a short delay.
///
/// TO CONNECT REAL AUTH:
///   1. Add `firebase_core`, `firebase_auth`, `google_sign_in`,
///      `sign_in_with_apple` to pubspec.yaml.
///   2. Run `flutterfire configure` and initialise Firebase in main().
///   3. Replace the bodies of [signInWithGoogle] / [signInWithApple] /
///      [verifyPhoneOtp] with the real SDK calls (signatures already match).
/// The rest of the app only depends on this class, so nothing else changes.
/// ─────────────────────────────────────────────────────────────────────────
class AuthService {
  AuthService(this._users);

  final UserRepository _users;
  final Random _random = Random();

  static const List<String> _sampleFirstNames = [
    'Alex', 'Sam', 'Jordan', 'Taylor', 'Riya', 'Kai', 'Noor', 'Leo', 'Maya',
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

  Future<SocialAuthResult> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final first = _sampleFirstNames[_random.nextInt(_sampleFirstNames.length)];
    final tag = _random.nextInt(9000) + 1000;
    return SocialAuthResult(
      email: '${first.toLowerCase()}$tag@gmail.com',
      name: first,
    );
  }

  Future<SocialAuthResult> signInWithApple() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
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
