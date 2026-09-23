import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A resolved device position (+ the city it is in, when known).
class LocationFix {
  const LocationFix({required this.lat, required this.lng, this.city});
  final double lat;
  final double lng;
  final String? city;
}

enum LocationStatus { ok, serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult(this.status, [this.fix]);
  final LocationStatus status;
  final LocationFix? fix;
  bool get ok => status == LocationStatus.ok && fix != null;
}

/// One place for everything location: permission prompts, GPS, reverse
/// geocoding (position → city) and place search (text → position).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _prefsCity = 'rovlo_last_city';
  static const String _prefsLat = 'rovlo_last_lat';
  static const String _prefsLng = 'rovlo_last_lng';
  static const Map<String, String> _osmHeaders = {
    'User-Agent': 'Rovlo/1.0 (Flutter app; rovlo.com)',
    'Accept-Language': 'en',
  };

  LocationFix? _last;
  LocationFix? get lastFix => _last;

  /// Last position we resolved in a previous session (instant, no GPS).
  Future<LocationFix?> cached() async {
    if (_last != null) return _last;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_prefsLat);
    final lng = prefs.getDouble(_prefsLng);
    if (lat == null || lng == null) return null;
    return _last = LocationFix(lat: lat, lng: lng, city: prefs.getString(_prefsCity));
  }

  /// Gets the current position. When [prompt] is false no permission dialog is
  /// shown — it only succeeds if permission was already granted.
  Future<LocationResult> locate({bool prompt = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && prompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return const LocationResult(LocationStatus.unavailable);

      final city = await reverseCity(pos.latitude, pos.longitude);
      final fix = LocationFix(lat: pos.latitude, lng: pos.longitude, city: city);
      await _remember(fix);
      return LocationResult(LocationStatus.ok, fix);
    } catch (e) {
      debugPrint('[LocationService] locate failed: $e');
      return const LocationResult(LocationStatus.unavailable);
    }
  }

  Future<void> _remember(LocationFix fix) async {
    _last = fix;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsLat, fix.lat);
    await prefs.setDouble(_prefsLng, fix.lng);
    if (fix.city != null) await prefs.setString(_prefsCity, fix.city!);
  }

  /// Position → city name. Uses the phone's geocoder first, OpenStreetMap
  /// Nominatim as a fallback (some devices ship without a geocoder).
  Future<String?> reverseCity(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      for (final m in marks) {
        final c = _firstNonEmpty([m.locality, m.subAdministrativeArea, m.administrativeArea]);
        if (c != null) return c;
      }
    } catch (_) {/* fall through */}

    try {
      final res = await http
          .get(
            Uri.parse('https://nominatim.openstreetmap.org/reverse'
                '?format=jsonv2&zoom=10&lat=$lat&lon=$lng'),
            headers: _osmHeaders,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final addr = (jsonDecode(res.body) as Map)['address'] as Map?;
        if (addr != null) {
          return _firstNonEmpty([
            addr['city'] as String?,
            addr['town'] as String?,
            addr['village'] as String?,
            addr['county'] as String?,
            addr['state'] as String?,
          ]);
        }
      }
    } catch (_) {}
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Text → places (OpenStreetMap Nominatim). Call at most once per second and
  /// only on explicit user action (their usage policy).
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final res = await http
          .get(
            Uri.parse('https://nominatim.openstreetmap.org/search'
                '?format=jsonv2&limit=6&addressdetails=1&q=${Uri.encodeQueryComponent(q)}'),
            headers: _osmHeaders,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final list = jsonDecode(res.body) as List;
      return list.map((e) {
        final m = e as Map;
        final addr = (m['address'] as Map?) ?? const {};
        final city = _firstNonEmpty([
          addr['city'] as String?,
          addr['town'] as String?,
          addr['village'] as String?,
          addr['state'] as String?,
        ]);
        return PlaceResult(
          name: (m['display_name'] as String?) ?? q,
          city: city,
          lat: double.parse(m['lat'].toString()),
          lng: double.parse(m['lon'].toString()),
        );
      }).toList();
    } catch (e) {
      debugPrint('[LocationService] search failed: $e');
      return const [];
    }
  }

  Future<void> openSettings(LocationStatus status) async {
    if (status == LocationStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.lat,
    required this.lng,
    this.city,
  });
  final String name;
  final String? city;
  final double lat;
  final double lng;
}
