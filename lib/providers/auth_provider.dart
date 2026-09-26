import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/backend/backend.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/support_service.dart';
import '../services/user_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Central session state: who is signed in and their profile.
///
/// The session itself lives in Supabase Auth (persisted + auto-refreshed), the
/// profile lives in the `profiles` table. A copy of the last profile is cached
/// on the device only so the app can still open when the phone is offline.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserRepository? userRepository})
      : _users = userRepository ?? UserRepository() {
    _auth = authService ?? AuthService(_users);
    _init();
  }

  static const String _cacheKey = 'rovlo_cached_profile';

  final UserRepository _users;
  late final AuthService _auth;
  StreamSubscription<sb.AuthState>? _authSub;

  AuthService get auth => _auth;
  UserRepository get users => _users;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool _isAdmin = false;
  bool _isSupportAgent = false;

  /// True for accounts listed in the `support_agents` table (they get the
  /// support inbox). Decided by the database.
  bool get isSupportAgent => _isSupportAgent;

  /// Decided by the database (`is_admin()`), not by anything in the app.
  /// It only controls what the UI shows — the real protection is Row Level
  /// Security, which rejects admin actions from non-admins anyway.
  bool get isAdmin => _isAdmin;

  /// A pending phone number captured before social auth during account creation.
  String? pendingPhoneNumber;

  bool _busy = false;
  bool get busy => _busy;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Start-up / session restore
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    if (!Backend.ready) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _authSub = _auth.authStateChanges.listen(_onAuthEvent);
    await _restore();
  }

  void _onAuthEvent(sb.AuthState state) {
    if (state.event == sb.AuthChangeEvent.signedOut &&
        _status == AuthStatus.signedIn) {
      // Session expired / revoked / signed out elsewhere.
      _clear();
    }
  }

  Future<void> _restore() async {
    final authUser = _auth.currentAuthUser;
    if (authUser == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    try {
      var user = await _users.findById(authUser.id);
      user ??= await _auth.resolveProfile(
        userId: authUser.id,
        email: authUser.email,
        name: authUser.userMetadata?['full_name'] as String? ??
            authUser.userMetadata?['name'] as String?,
        method: AuthMethod.google,
        photoUrl: authUser.userMetadata?['avatar_url'] as String?,
      );

      if (user.isBlocked) {
        await _auth.signOut();
        _clear();
        return;
      }
      await _commit(user);
    } catch (e) {
      debugPrint('[AuthProvider] restore failed (offline?): $e');
      final cached = await _readCache(authUser.id);
      if (cached != null && !cached.isBlocked) {
        _currentUser = cached;
        _status = AuthStatus.signedIn;
      } else {
        _status = AuthStatus.signedOut;
      }
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Local offline cache
  // ---------------------------------------------------------------------------

  Future<void> _writeCache(AppUser? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove(_cacheKey);
      } else {
        await prefs.setString(
          _cacheKey,
          jsonEncode({
            ...user.toRow(),
            'created_at': user.createdAt.toIso8601String(),
            'is_blocked': user.isBlocked,
          }),
        );
      }
    } catch (_) {}
  }

  Future<AppUser?> _readCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final user = AppUser.fromRow(jsonDecode(raw) as Map<String, dynamic>);
      return user.id == userId ? user : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Commit / clear
  // ---------------------------------------------------------------------------

  Future<void> _commit(AppUser user) async {
    _isAdmin = await _users.isAdmin();
    _isSupportAgent = await SupportService.instance.isAgent();
    _currentUser = user;
    _status = AuthStatus.signedIn;
    unawaited(_writeCache(user));
    notifyListeners();

    // Live broadcasts + push token (never block sign-in on these).
    NotificationService().start();
    unawaited(PushNotificationService().bindUser(user.id));
  }

  void _clear() {
    _currentUser = null;
    _isAdmin = false;
    _isSupportAgent = false;
    _status = AuthStatus.signedOut;
    pendingPhoneNumber = null;
    unawaited(_writeCache(null));
    unawaited(NotificationService().stop());
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sign in (existing users): straight to social auth.
  // ---------------------------------------------------------------------------

  Future<AppUser?> signInWithGoogle() =>
      _social(() => _auth.signInWithGoogle(), AuthMethod.google);

  Future<AppUser?> signInWithApple() =>
      _social(() => _auth.signInWithApple(), AuthMethod.apple);

  /// Debug builds only: a throw-away guest account.
  Future<AppUser?> signInDemo() =>
      _social(() => _auth.signInAnonymously(), AuthMethod.phone);

  Future<AppUser?> _social(
    Future<SocialAuthResult?> Function() run,
    AuthMethod method,
  ) async {
    if (!Backend.ready) {
      throw const AuthException(
        'The app is not connected to its server. Build it with '
        '--dart-define-from-file=.env (see SUPABASE_SETUP.md).',
      );
    }
    _setBusy(true);
    try {
      final result = await run();
      if (result == null) return null; // user cancelled the picker

      final user = await _auth.resolveProfile(
        userId: result.userId,
        email: result.email,
        name: result.name,
        phoneNumber: pendingPhoneNumber,
        method: method,
        photoUrl: result.photoUrl,
      );
      if (user.isBlocked) {
        await _auth.signOut();
        throw const AuthException('This account has been suspended.');
      }
      pendingPhoneNumber = null;
      await _commit(user);
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

  // ---------------------------------------------------------------------------
  // Profile edits — every one is written to the database first, and the local
  // copy only changes once the write succeeded.
  // ---------------------------------------------------------------------------

  Future<void> _apply(AppUser updated) async {
    await _auth.updateUser(updated);
    _currentUser = updated;
    unawaited(_writeCache(updated));
    notifyListeners();
  }

  Future<void> setName(String name) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(name: name.trim()));
  }

  Future<void> setGender(String gender) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(gender: gender));
  }

  /// Photos may be local file paths (just picked) or URLs; local ones are
  /// uploaded to Storage first so other users can see them.
  Future<void> setPhotos(List<String> photos) async {
    final u = _currentUser;
    if (u == null) return;
    final urls = await MediaService.instance.ensureAllRemote(photos);
    await _apply(u.copyWith(
      profilePhotos: urls,
      photoUrl: urls.isNotEmpty ? urls.first : u.photoUrl,
    ));
  }

  Future<void> togglePauseAccount() async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(isPaused: !u.isPaused));
  }

  Future<void> setDob(String dob) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(dob: dob));
  }

  Future<void> setHomeBase(String homeBase) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(homeBase: homeBase));
  }

  Future<void> setVerified(bool verified) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(isVerified: verified));
  }

  Future<void> setSubscriptionTier(String tier) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(subscriptionTier: tier));
  }

  Future<void> setEmergencyContacts(List<Map<String, String>> contacts) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(emergencyContacts: contacts));
  }

  Future<void> setTravelInterests(List<String> interests) async {
    final u = _currentUser;
    if (u == null) return;
    await _apply(u.copyWith(travelInterests: interests, profileComplete: true));
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? photoUrl,
    String? dob,
    String? homeBase,
    List<String>? profilePhotos,
  }) async {
    final u = _currentUser;
    if (u == null) return;

    String? uploadedMain;
    if (photoUrl != null) {
      uploadedMain = await MediaService.instance.ensureRemote(photoUrl);
    }
    List<String>? uploadedPhotos;
    if (profilePhotos != null) {
      uploadedPhotos = await MediaService.instance.ensureAllRemote(profilePhotos);
    }

    await _apply(u.copyWith(
      name: name?.trim() ?? u.name,
      bio: bio?.trim() ?? u.bio,
      photoUrl: uploadedMain ?? u.photoUrl,
      dob: dob ?? u.dob,
      homeBase: homeBase ?? u.homeBase,
      profilePhotos: uploadedPhotos ?? u.profilePhotos,
    ));
  }

  /// Saves the device position + city (used by the map and "near me").
  Future<void> updateLocation(double lat, double lng, String? city) async {
    final u = _currentUser;
    if (u == null || u.ghostMode) return;
    try {
      await _users.updateLocation(u.id, lat: lat, lng: lng, city: city);
      if (city != null && city.isNotEmpty && city != u.city) {
        _currentUser = u.copyWith(city: city);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] location update failed: $e');
    }
  }

  /// Saves only the city / district name (no coordinates) — used by the Hotlist.
  Future<void> updateCity(String? city) async {
    final u = _currentUser;
    final c = city?.trim() ?? '';
    if (u == null || c.isEmpty || c == u.city) return;
    try {
      await _users.patch(u.id, {'city': c});
      _currentUser = u.copyWith(city: c);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] city update failed: $e');
    }
  }

  /// Ghost mode hides me from the map and removes my stored coordinates.
  Future<void> setGhostMode(bool enabled) async {
    final u = _currentUser;
    if (u == null) return;
    await _users.patch(u.id, {
      'ghost_mode': enabled,
      if (enabled) 'lat': null,
      if (enabled) 'lng': null,
    });
    _currentUser = u.copyWith(ghostMode: enabled);
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final u = _currentUser;
    if (u == null) return;
    try {
      final fresh = await _users.findById(u.id);
      if (fresh == null) return;
      if (fresh.isBlocked) {
        await signOut();
        return;
      }
      _currentUser = fresh;
      _isAdmin = await _users.isAdmin();
      _isSupportAgent = await SupportService.instance.isAgent();
      unawaited(_writeCache(fresh));
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] refresh failed: $e');
    }
  }

  /// Signs out of Supabase and Google and forgets the local copy.
  Future<void> signOut() async {
    await PushNotificationService().unbindCurrentUser();
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthProvider] sign-out error (ignored): $e');
    }
    _clear();
  }

  /// Permanently deletes the account and all its data.
  Future<void> deleteAccount() async {
    await _auth.deleteMyAccount();
    _clear();
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
