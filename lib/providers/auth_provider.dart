import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Central session state: who is signed in, plus the in-progress onboarding
/// draft used while a new user completes their profile.
///
/// Session persistence is handled by Firebase Auth — the user stays logged in
/// across app restarts until they explicitly sign out.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserRepository? userRepository})
      : _users = userRepository ?? UserRepository() {
    _auth = authService ?? AuthService(_users);
    _restore();
    // Listen to Firebase auth state changes reactively
    _authSub = _auth.authStateChanges.listen(_onFirebaseAuthStateChanged);
  }

  static const String _sessionKey = 'rovlo_current_user_id';

  final UserRepository _users;
  late final AuthService _auth;
  StreamSubscription<fb.User?>? _authSub;

  AuthService get auth => _auth;
  UserRepository get users => _users;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool get isAdmin => AppConstants.isAdminEmail(_currentUser?.email);

  // A pending phone number captured before social auth during account creation.
  String? pendingPhoneNumber;

  bool _busy = false;
  bool get busy => _busy;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  /// Called by Firebase auth state listener when auth state changes.
  void _onFirebaseAuthStateChanged(fb.User? firebaseUser) {
    if (firebaseUser == null && _status == AuthStatus.signedIn) {
      // Firebase session expired or user signed out externally
      _currentUser = null;
      _status = AuthStatus.signedOut;
      _persistSession(null);
      notifyListeners();
    }
  }

  /// Restore session: first check Firebase Auth for a persistent login,
  /// then fall back to SharedPreferences for the AppUser profile data.
  Future<void> _restore() async {
    // Check if Firebase has a persisted user session
    final fb.User? firebaseUser = _auth.firebaseCurrentUser;

    if (firebaseUser != null) {
      // Firebase user is still authenticated — restore their AppUser profile
      // Try to find by email first (most reliable)
      AppUser? user;
      if (firebaseUser.email != null) {
        user = await _users.findByEmail(firebaseUser.email!);
      }
      // Fallback: try by Firebase UID
      user ??= await _users.findById(firebaseUser.uid);

      if (user != null && !user.isBlocked) {
        _currentUser = user;
        _status = AuthStatus.signedIn;
        notifyListeners();
        return;
      }

      // Firebase user exists but no local profile — might be a fresh install
      // with a previously authenticated account. Create a minimal profile.
      if (user == null) {
        final newUser = await _auth.resolveOrCreate(
          email: firebaseUser.email ?? '${firebaseUser.uid}@rovlo.app',
          name: firebaseUser.displayName,
          method: AuthMethod.google,
          photoUrl: firebaseUser.photoURL,
          firebaseUid: firebaseUser.uid,
        );
        _currentUser = newUser;
        _status = AuthStatus.signedIn;
        await _persistSession(newUser);
        notifyListeners();
        return;
      }
    }

    // Fallback: check SharedPreferences for legacy session
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionKey);
    if (id != null) {
      final user = await _users.findById(id);
      if (user != null && !user.isBlocked) {
        _currentUser = user;
        _status = AuthStatus.signedIn;
        notifyListeners();
        return;
      }
    }
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _persistSession(AppUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, user.id);
    }
  }

  void _commit(AppUser user) {
    _currentUser = user;
    _status = AuthStatus.signedIn;
    _persistSession(user);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sign in (existing users): straight to social auth.
  // ---------------------------------------------------------------------------

  Future<AppUser?> signInWithGoogle() => _social(
        () => _auth.signInWithGoogle(),
        AuthMethod.google,
      );
  Future<AppUser?> signInWithApple() => _social(
        () => _auth.signInWithApple(),
        AuthMethod.apple,
      );

  Future<AppUser?> signInDemo() => _social(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          return const SocialAuthResult(
            email: 'demo.traveler@rovlo.com',
            name: 'Demo Traveler',
            photoUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Demo',
          );
        },
        AuthMethod.google,
      );

  Future<AppUser?> _social(
    Future<SocialAuthResult?> Function() run,
    AuthMethod method,
  ) async {
    _setBusy(true);
    try {
      final result = await run();
      if (result == null) {
        // User cancelled the sign-in picker
        return null;
      }
      final user = await _auth.resolveOrCreate(
        email: result.email,
        name: result.name,
        phoneNumber: pendingPhoneNumber,
        method: method,
        photoUrl: result.photoUrl,
        firebaseUid: result.firebaseUid,
      );
      if (user.isBlocked) {
        _setBusy(false);
        throw const AuthException('This account has been suspended.');
      }
      pendingPhoneNumber = null;
      _commit(user);
      return user;
    } finally {
      _setBusy(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Create account: phone -> otp -> social -> profile steps.
  // ---------------------------------------------------------------------------

  Future<void> requestOtp(String phoneNumber) async {
    _setBusy(true);
    try {
      pendingPhoneNumber = phoneNumber;
      await _auth.requestPhoneOtp(phoneNumber);
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verifyOtp(String code) async {
    _setBusy(true);
    try {
      return await _auth.verifyPhoneOtp(pendingPhoneNumber ?? '', code);
    } finally {
      _setBusy(false);
    }
  }

  /// Updates the current user's name during profile setup.
  Future<void> setName(String name) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(name: name.trim());
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setGender(String gender) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(gender: gender);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setPhotos(List<String> photos) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(
      profilePhotos: photos,
      photoUrl: photos.isNotEmpty ? photos.first : user.photoUrl,
    );
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> togglePauseAccount() async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(isPaused: !user.isPaused);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setDob(String dob) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(dob: dob);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setHomeBase(String homeBase) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(homeBase: homeBase);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setVerified(bool verified) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(isVerified: verified);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setSubscriptionTier(String tier) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(subscriptionTier: tier);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setEmergencyContacts(List<Map<String, String>> contacts) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(emergencyContacts: contacts);
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setTravelInterests(List<String> interests) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(
      travelInterests: interests,
      profileComplete: true,
    );
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? photoUrl,
    String? dob,
    String? homeBase,
    List<String>? profilePhotos,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(
      name: name?.trim() ?? user.name,
      bio: bio?.trim() ?? user.bio,
      photoUrl: photoUrl ?? user.photoUrl,
      dob: dob ?? user.dob,
      homeBase: homeBase ?? user.homeBase,
      profilePhotos: profilePhotos ?? user.profilePhotos,
    );
    await _auth.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final user = _currentUser;
    if (user == null) return;
    final fresh = await _users.findById(user.id);
    if (fresh != null) {
      _currentUser = fresh;
      notifyListeners();
    }
  }

  /// Signs out from both Firebase Auth and the local session.
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _status = AuthStatus.signedOut;
    pendingPhoneNumber = null;
    await _persistSession(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
