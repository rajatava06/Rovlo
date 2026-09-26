import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Where the person is right now, as sent in an SOS.
class SosSnapshot {
  const SosSnapshot({
    required this.lat,
    required this.lng,
    required this.address,
    required this.countryCode,
    this.accuracyMeters,
  });

  final double lat;
  final double lng;

  /// Street-level address (an SOS is the one place exact location is wanted).
  final String address;
  final String? countryCode;
  final double? accuracyMeters;

  String get mapsLink => 'https://www.google.com/maps?q=$lat,$lng';
}

enum SosLocationProblem { serviceOff, denied, deniedForever, unavailable }

class SosLocationResult {
  const SosLocationResult.ok(this.snapshot) : problem = null;
  const SosLocationResult.problem(this.problem) : snapshot = null;
  final SosSnapshot? snapshot;
  final SosLocationProblem? problem;
}

/// Everything behind the SOS button: the loud siren, the exact location and the
/// message that is texted / shared.
///
/// What the app can and cannot do (be honest with users):
///  * it plays a loud alarm, gets the exact location and address,
///  * it opens the phone dialler on the local emergency number and the SMS app
///    with the message + Google Maps link already written for the emergency
///    contacts — the person taps Call / Send (Android and iOS do not let an app
///    place a call or send an SMS silently, and Google Play forbids it),
///  * it cannot itself dispatch police / ambulance.
class SosService {
  SosService();

  static const MethodChannel _native = MethodChannel('rovlo/sos');

  final AudioPlayer _player = AudioPlayer();
  int? _previousAlarmVolume;
  bool _playing = false;

  bool get playing => _playing;

  // ── Siren ───────────────────────────────────────────────────────────────────

  /// Starts the looping siren on the ALARM stream at maximum volume. It is
  /// audible even when the phone is on silent.
  Future<void> startSiren() async {
    if (_playing) return;
    _playing = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _previousAlarmVolume ??= await _native.invokeMethod<int>('maxAlarmVolume');
      }
    } catch (e) {
      debugPrint('[SOS] could not raise the alarm volume: $e');
    }
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/sos_siren.wav'), volume: 1.0);
    } catch (e) {
      _playing = false;
      debugPrint('[SOS] siren failed: $e');
    }
  }

  Future<void> pauseSiren() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.pause();
    } catch (_) {}
  }

  /// Stops the siren and puts the user's alarm volume back.
  Future<void> stopSiren() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
    final prev = _previousAlarmVolume;
    _previousAlarmVolume = null;
    if (prev != null) {
      try {
        await _native.invokeMethod('restoreAlarmVolume', {'level': prev});
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stopSiren();
    await _player.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<SosLocationResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const SosLocationResult.problem(SosLocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const SosLocationResult.problem(SosLocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const SosLocationResult.problem(SosLocationProblem.denied);
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        return const SosLocationResult.problem(SosLocationProblem.unavailable);
      }

      var address = '';
      String? iso;
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 6));
        if (marks.isNotEmpty) {
          address = formatAddress(marks.first);
          iso = marks.first.isoCountryCode;
        }
      } catch (_) {
        // No geocoder / no internet: the coordinates + map link still work.
      }
      return SosLocationResult.ok(SosSnapshot(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
        countryCode: iso,
        accuracyMeters: pos.accuracy,
      ));
    } catch (e) {
      debugPrint('[SOS] locate failed: $e');
      return const SosLocationResult.problem(SosLocationProblem.unavailable);
    }
  }

  static String formatAddress(Placemark m) {
    final parts = <String>[];
    void add(String? v) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
    }

    add(m.name);
    add(m.street);
    add(m.subLocality);
    add(m.locality);
    add(m.subAdministrativeArea);
    add(m.administrativeArea);
    add(m.postalCode);
    return parts.join(', ');
  }

  // ── Message + numbers (pure, unit-tested) ───────────────────────────────────

  /// Local emergency number for a country (ISO code). 112 is the default: it
  /// works in India, the EU and on most mobile networks worldwide.
  static String emergencyNumber(String? isoCountry) {
    switch ((isoCountry ?? '').toUpperCase()) {
      case 'US':
      case 'CA':
        return '911';
      case 'GB':
        return '999';
      case 'AU':
        return '000';
      case 'NZ':
        return '111';
      default:
        return '112';
    }
  }

  static String buildMessage({required String name, SosSnapshot? location}) {
    final who = name.trim().isEmpty ? 'A Rovlo traveler' : name.trim();
    final b = StringBuffer('🚨 EMERGENCY! $who needs help right now.');
    if (location != null) {
      b.write('\nMy location: ${location.mapsLink}');
      if (location.address.isNotEmpty) b.write('\nAddress: ${location.address}');
    } else {
      b.write('\nI could not get my exact location — please call me.');
    }
    b.write('\nSent from Rovlo SOS.');
    return b.toString();
  }

  /// Keeps only dialable characters of each contact's phone number.
  static List<String> cleanNumbers(List<Map<String, String>> contacts) {
    final out = <String>[];
    for (final c in contacts) {
      final raw = (c['phone'] ?? '').trim();
      final n = raw.replaceAll(RegExp(r'[^0-9+]'), '');
      if (n.replaceAll('+', '').length >= 5 && !out.contains(n)) out.add(n);
    }
    return out;
  }

  /// `sms:` link with the message pre-filled. `%20` (not `+`) for spaces —
  /// several SMS apps would otherwise show literal plus signs.
  static Uri smsUri(List<String> numbers, String body, {required bool ios}) {
    final sep = ios ? '&' : '?';
    return Uri.parse('sms:${numbers.join(',')}${sep}body=${Uri.encodeComponent(body)}');
  }
}
