import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// App configuration. Nothing here is hard-coded in the source: values come
/// from either
///   1. `--dart-define-from-file=.env` (used by CI / release scripts), or
///   2. `assets/config/app_config.json` — a git-ignored file bundled into the
///      app (copy `app_config.example.json` and fill it in).
/// so a plain `flutter run`, the IDE Run button and a release build all work.
///
/// The Supabase URL + *publishable* key, the Google Web client id and the map
/// key are public by design (they ship inside every app; Row Level Security
/// protects the data). NEVER put the `sb_secret_…` / service_role key here.
class Env {
  Env._();

  static Map<String, dynamic> _file = const {};

  /// Loads the bundled config file. Call once at start-up, before Supabase.
  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config/app_config.json');
      _file = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _file = const {};
    }
  }

  static String _pick(String define, String key) {
    if (define.isNotEmpty) return define;
    final v = _file[key];
    return v is String ? v.trim() : '';
  }

  static const String _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _googleDefine =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String _mapDefine = String.fromEnvironment('MAPTILER_KEY');

  static String get supabaseUrl => _pick(_urlDefine, 'SUPABASE_URL');
  static String get supabaseAnonKey => _pick(_keyDefine, 'SUPABASE_ANON_KEY');

  /// OAuth *Web* client id (same one that is pasted into Supabase →
  /// Authentication → Providers → Google).
  static String get googleWebClientId =>
      _pick(_googleDefine, 'GOOGLE_WEB_CLIENT_ID');

  /// Optional MapTiler key; without it the map uses OpenStreetMap / Esri tiles.
  static String get mapTilerKey => _pick(_mapDefine, 'MAPTILER_KEY');

  static bool get supabaseConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.isNotEmpty;
}
