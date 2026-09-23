import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper around the Supabase client so the rest of the app never
/// touches `Supabase.instance` directly.
class Backend {
  Backend._();

  static bool _ready = false;

  /// True once Supabase has been initialised with valid credentials.
  static bool get ready => _ready;

  static SupabaseClient get client => Supabase.instance.client;

  /// Currently signed-in auth user id (null when signed out / not configured).
  static String? get uid => _ready ? client.auth.currentUser?.id : null;

  static Future<void> init() async {
    if (!Env.supabaseConfigured) {
      debugPrint('[Rovlo] SUPABASE_URL / SUPABASE_ANON_KEY missing — run with '
          '--dart-define-from-file=.env');
      return;
    }
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
      _ready = true;
    } catch (e) {
      debugPrint('[Rovlo] Supabase init failed: $e');
    }
  }
}
