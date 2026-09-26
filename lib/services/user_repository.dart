import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/app_user.dart';

/// Reads and writes user profiles in Supabase (`public.profiles`).
///
/// What each caller may do is enforced by Row Level Security in the database:
/// normal users can only touch their own row, admins can see / block / delete
/// everyone. This class is only a convenient, typed doorway.
class UserRepository {
  SupabaseClient get _db => Backend.client;

  // ── Reads ───────────────────────────────────────────────────────────────────

  Future<AppUser?> findById(String id) async {
    final row = await _db.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : AppUser.fromRow(row);
  }

  /// Admin only (RLS returns just your own row for everyone else).
  Future<List<AppUser>> getAllUsers() async {
    final rows = await _db
        .from('profiles')
        .select()
        .order('created_at', ascending: false)
        .limit(1000);
    return rows.map<AppUser>(AppUser.fromRow).toList();
  }

  // ── Writes (own profile) ────────────────────────────────────────────────────

  /// Inserts or updates the signed-in user's own profile.
  Future<void> upsert(AppUser user) async {
    await _db.from('profiles').upsert(user.toRow());
  }

  Future<void> patch(String id, Map<String, dynamic> values) async {
    await _db.from('profiles').update(values).eq('id', id);
  }

  Future<void> updateLocation(
    String id, {
    required double lat,
    required double lng,
    String? city,
  }) =>
      patch(id, {
        'lat': lat,
        'lng': lng,
        if (city != null && city.isNotEmpty) 'city': city,
        'location_updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> setFcmToken(String id, String? token) =>
      patch(id, {'fcm_token': token});

  // ── Admin actions ───────────────────────────────────────────────────────────

  Future<void> setBlocked(String id, bool blocked) =>
      patch(id, {'is_blocked': blocked});

  /// Removes the account completely (auth user + profile + all its data).
  Future<void> delete(String id) async {
    await _db.rpc('admin_delete_user', params: {'p_user': id});
  }

  Future<Set<String>> adminEmails() async {
    try {
      final rows = await _db.from('admin_emails').select('email');
      return rows.map<String>((r) => (r['email'] as String).toLowerCase()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> isAdmin() async {
    try {
      final res = await _db.rpc('is_admin');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, int>> stats() async {
    final res = await _db.rpc('admin_stats');
    final map = Map<String, dynamic>.from(res as Map);
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// Whole roster as pretty JSON (used by the admin panel's export button).
  Future<String> exportJson() async {
    final users = await getAllUsers();
    return const JsonEncoder.withIndent('  ')
        .convert(users.map((u) => u.toMap()).toList());
  }
}
