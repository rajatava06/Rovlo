import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Central session state: who is signed in, plus the in-progress onboarding
/// draft used while a new user completes their profile.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserRepository? userRepository})
      : _users = userRepository ?? UserRepository() {
    _auth = authService ?? AuthService(_users);
    _restore();
  }

  static const String _sessionKey = 'rovlo_current_user_id';

  final UserRepository _users;
  late final AuthService _auth;

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

  Future<void> _restore() async {
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

  Future<AppUser?> signInWithGoogle() => _social(_auth.signInWithGoogle,
      AuthMethod.google);
  Future<AppUser?> signInWithApple() =>
      _social(_auth.signInWithApple, AuthMethod.apple);

  Future<AppUser?> _social(
    Future<SocialAuthResult> Function() run,
    AuthMethod method,
  ) async {
    _setBusy(true);
    try {
      final result = await run();
      final user = await _auth.resolveOrCreate(
        email: result.email,
        name: result.name,
        phoneNumber: pendingPhoneNumber,
        method: method,
        photoUrl: result.photoUrl,
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

  Future<void> updateProfile({String? name, String? bio, String? photoUrl}) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(
      name: name?.trim() ?? user.name,
      bio: bio?.trim() ?? user.bio,
      photoUrl: photoUrl ?? user.photoUrl,
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

  Future<void> signOut() async {
    _currentUser = null;
    _status = AuthStatus.signedOut;
    pendingPhoneNumber = null;
    await _persistSession(null);
    notifyListeners();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
