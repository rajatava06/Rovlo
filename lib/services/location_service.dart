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
    final saved = prefs.getString(_prefsCity);
    return _last = LocationFix(
      lat: lat,
      lng: lng,
      city: saved == null ? null : cleanCityName(saved),
    );
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

  static final RegExp _cityPrefix =
      RegExp(r'^(city|municipality|district|corporation) of\s+', caseSensitive: false);
  static final RegExp _citySuffix = RegExp(
    r'\s+(municipal corporation|municipal council|municipality|metropolitan (city|area|region|corporation)|'
    r'city corporation|corporation|nagar nigam|nagar palika|mahanagar palika|urban agglomeration|'
    r'development authority|district|division|tehsil|tahsil|taluk|taluka|mandal|block|city|town|urban|rural)$',
    caseSensitive: false,
  );

  /// Boils a place name down to the plain city / district people search for:
  /// "Bhubaneswar Municipal Corporation" → "Bhubaneswar", "Khordha District" →
  /// "Khordha". Falls back to the input if nothing would be left.
  static String cleanCityName(String raw) {
    var s = raw.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    s = s.replaceFirst(_cityPrefix, '');
    String prev;
    do {
      prev = s;
      s = s.replaceFirst(_citySuffix, '').trim();
    } while (s != prev && s.isNotEmpty);
    return s.isEmpty ? raw.trim() : s;
  }

  /// Position → city name. Uses the phone's geocoder first, OpenStreetMap
  /// Nominatim as a fallback (some devices ship without a geocoder).
  Future<String?> reverseCity(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      for (final m in marks) {
        final c = _firstNonEmpty([m.locality, m.subAdministrativeArea, m.administrativeArea]);
        if (c != null) return cleanCityName(c);
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
          final c = _firstNonEmpty([
            addr['city'] as String?,
            addr['town'] as String?,
            addr['village'] as String?,
            addr['county'] as String?,
            addr['state'] as String?,
          ]);
          return c == null ? null : cleanCityName(c);
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

  /// Destination search for "Going to…": cities, islands, regions, countries.
  /// Uses Photon (free, no API key, built for search-as-you-type on OpenStreetMap
  /// data) and falls back to Nominatim if Photon is unreachable.
  Future<List<PlaceResult>> searchDestinations(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final res = await http
          .get(
            Uri.parse('https://photon.komoot.io/api/'
                '?limit=8&lang=en&osm_tag=place&q=${Uri.encodeQueryComponent(q)}'),
            headers: _osmHeaders,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final features = (jsonDecode(res.body) as Map)['features'] as List? ?? const [];
        final seen = <String>{};
        final out = <PlaceResult>[];
        for (final f in features) {
          final props = ((f as Map)['properties'] as Map?) ?? const {};
          final coords = ((f['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
          final title = _firstNonEmpty([props['name'] as String?]);
          if (title == null || coords.length < 2) continue;
          final state = _firstNonEmpty([props['state'] as String?]);
          final country = _firstNonEmpty([props['country'] as String?]);
          final subtitle = [
            if (state != null && state != title) state,
            if (country != null && country != title) country,
          ].join(', ');
          final place = PlaceResult(
            name: [title, if (subtitle.isNotEmpty) subtitle].join(', '),
            city: title,
            lat: (coords[1] as num).toDouble(),
            lng: (coords[0] as num).toDouble(),
            title: title,
            subtitle: subtitle,
          );
          if (seen.add(place.label.toLowerCase())) out.add(place);
        }
        return out;
      }
    } catch (e) {
      debugPrint('[LocationService] photon search failed: $e');
    }

    final fallback = await searchPlaces(q);
    return [
      for (final r in fallback)
        PlaceResult(
          name: r.name,
          city: r.city,
          lat: r.lat,
          lng: r.lng,
          title: r.city ?? r.name.split(',').first.trim(),
          subtitle: r.name.split(',').skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList().reversed.take(1).join(', '),
        ),
    ];
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
    this.title,
    this.subtitle,
  });
  final String name;
  final String? city;
  final double lat;
  final double lng;

  /// Short name ("Bali") and the region/country line ("Indonesia") — set by
  /// [LocationService.searchDestinations].
  final String? title;
  final String? subtitle;

  /// What we store as the trip destination: "Bali, Indonesia".
  String get label {
    final t = title;
    if (t == null || t.isEmpty) return name;
    final sub = subtitle;
    return (sub == null || sub.isEmpty) ? t : '$t, $sub';
  }
}
