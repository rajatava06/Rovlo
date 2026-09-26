import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/hot_event.dart';

/// Hotlist data. Events live in `public.events`; the `sync-events` Edge
/// Function fills that table for a city from Google Events / Ticketmaster.
class EventsRepository {
  SupabaseClient get _db => Backend.client;

  // Must mirror CITY_ALIASES in supabase/functions/sync-events/index.ts
  static const Map<String, String> _aliases = {
    'bangalore': 'bengaluru',
    'bombay': 'mumbai',
    'calcutta': 'kolkata',
    'madras': 'chennai',
    'new delhi': 'delhi',
    'delhi ncr': 'delhi',
    'gurgaon': 'gurugram',
    'new york city': 'new york',
  };

  static String cityKey(String city) {
    final k = city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _aliases[k] ?? k;
  }

  /// Events already stored for [city] (fast, no external call).
  Future<List<HotEvent>> cached(String city) async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final rows = await _db
        .from('events')
        .select()
        .eq('city_key', cityKey(city))
        .eq('is_active', true)
        .or('starts_at.is.null,starts_at.gte.${since.toIso8601String()}')
        .order('is_featured', ascending: false)
        .order('starts_at', ascending: true, nullsFirst: false)
        .limit(120);
    return rows.map<HotEvent>(HotEvent.fromRow).toList();
  }

  /// Asks the server to refresh [city] from the event providers. The server
  /// caches per city, so calling this often is cheap. Returns true when new
  /// data may have been written.
  Future<bool> sync(String city, {double? lat, double? lng, bool force = false}) async {
    try {
      final res = await _db.functions.invoke('sync-events', body: {
        'city': city,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (force) 'force': true,
      });
      final data = res.data;
      return data is Map && data['cached'] != true;
    } catch (e) {
      debugPrint('[EventsRepository] sync failed: $e');
      return false;
    }
  }

  /// Cities that currently have events (used to suggest places to browse).
  Future<List<String>> citiesWithEvents() async {
    try {
      final rows = await _db.from('events').select('city').eq('is_active', true).limit(500);
      final counts = <String, int>{};
      for (final r in rows) {
        final c = (r['city'] as String?)?.trim();
        if (c != null && c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
      }
      final cities = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      return cities.take(12).toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Saved events ────────────────────────────────────────────────────────────

  Future<Set<String>> savedIds() async {
    final uid = Backend.uid;
    if (uid == null) return <String>{};
    try {
      final rows = await _db.from('saved_events').select('event_id').eq('user_id', uid);
      return rows.map<String>((r) => r['event_id'] as String).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setSaved(String eventId, bool saved) async {
    final uid = Backend.uid;
    if (uid == null) return;
    if (saved) {
      await _db.from('saved_events').upsert({'user_id': uid, 'event_id': eventId});
    } else {
      await _db.from('saved_events').delete().eq('user_id', uid).eq('event_id', eventId);
    }
  }
}
