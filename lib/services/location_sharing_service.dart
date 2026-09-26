import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'location_service.dart';

/// Keeps my position fresh on the server while the app is open, so other
/// travellers see me on *their* map (unless Ghost Mode is on).
///
/// Runs app-wide from the home screen — people don't have to open the map tab
/// to be visible. Only the coarse position is used by others (rounded to
/// ~100 m by the database) and it is never written while Ghost Mode is on.
class LocationSharingService with WidgetsBindingObserver {
  LocationSharingService._();
  static final LocationSharingService instance = LocationSharingService._();

  static const Duration _interval = Duration(seconds: 45);
  static const Duration _maxAge = Duration(minutes: 8);
  static const double _minMoveMeters = 40;
  static const String _promptedKey = 'rovlo_location_prompted';

  AuthProvider? _auth;
  Timer? _timer;
  Position? _last;
  String? _city;
  DateTime? _lastWrite;
  bool _busy = false;
  bool _observing = false;

  void start(AuthProvider auth) {
    _auth = auth;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _tick());
    unawaited(_tick(firstRun: true));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _auth = null;
    _last = null;
    _lastWrite = null;
    if (_observing) {
      _observing = false;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth == null) return;
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = Timer.periodic(_interval, (_) => _tick());
      unawaited(_tick());
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Forces the next tick to write (e.g. right after Ghost Mode is turned off).
  void refreshSoon() {
    _lastWrite = null;
    unawaited(_tick());
  }

  Future<void> _tick({bool firstRun = false}) async {
    final auth = _auth;
    if (auth == null || _busy) return;
    final user = auth.currentUser;
    if (user == null || user.ghostMode) return;

    _busy = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && firstRun) {
        // Ask once, ever. After that the Map tab explains how to enable it.
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_promptedKey) ?? false)) {
          await prefs.setBool(_promptedKey, true);
          permission = await Geolocator.requestPermission();
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;

      final moved = _last == null
          ? double.infinity
          : Geolocator.distanceBetween(
              _last!.latitude, _last!.longitude, pos.latitude, pos.longitude);
      final stale = _lastWrite == null ||
          DateTime.now().difference(_lastWrite!) > _maxAge;
      if (moved < _minMoveMeters && !stale) return;

      // The city only changes when I travel — don't hit the geocoder every time.
      if (_city == null || moved > 3000) {
        _city = await LocationService.instance.reverseCity(pos.latitude, pos.longitude);
      }
      await auth.updateLocation(pos.latitude, pos.longitude, _city);
      _last = pos;
      _lastWrite = DateTime.now();
    } catch (e) {
      debugPrint('[LocationSharing] tick failed: $e');
    } finally {
      _busy = false;
    }
  }
}
