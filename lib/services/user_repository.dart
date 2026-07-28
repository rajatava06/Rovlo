import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Stores the roster of Rovlo users.
///
/// This local implementation (backed by [SharedPreferences]) keeps the app
/// fully functional and launchable with no backend. Swap the read/write bodies
/// for Firestore / a REST API when you connect a real backend — the rest of the
/// app talks only to this interface.
class UserRepository {
  static const String _usersKey = 'rovlo_users';

  Future<List<AppUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_usersKey) ?? const <String>[];
    final users = raw
        .map((s) {
          try {
            return AppUser.fromJson(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppUser>()
        .toList();
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  Future<void> _saveAll(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _usersKey,
      users.map((u) => u.toJson()).toList(),
    );
  }

  Future<AppUser?> findById(String id) async {
    final users = await getAllUsers();
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<AppUser?> findByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final users = await getAllUsers();
    for (final u in users) {
      if ((u.email ?? '').toLowerCase() == normalized) return u;
    }
    return null;
  }

  Future<AppUser?> findByPhone(String phone) async {
    final users = await getAllUsers();
    for (final u in users) {
      if (u.phoneNumber == phone) return u;
    }
    return null;
  }

  /// Inserts or updates a user (matched by id).
  Future<void> upsert(AppUser user) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    await _saveAll(users);
  }

  Future<void> delete(String id) async {
    final users = await getAllUsers();
    users.removeWhere((u) => u.id == id);
    await _saveAll(users);
  }

  Future<void> setBlocked(String id, bool blocked) async {
    final user = await findById(id);
    if (user == null) return;
    await upsert(user.copyWith(isBlocked: blocked));
  }

  /// Convenience for the admin dashboard.
  Future<Map<String, int>> stats() async {
    final users = await getAllUsers();
    final now = DateTime.now();
    final newToday = users
        .where((u) => now.difference(u.createdAt).inDays == 0)
        .length;
    final active = users.where((u) => !u.isBlocked && !u.isPaused).length;
    final blocked = users.where((u) => u.isBlocked).length;
    final verified = users.where((u) => u.isVerified).length;
    final complete = users.where((u) => u.profileComplete).length;
    return {
      'total': users.length,
      'active': active,
      'blocked': blocked,
      'verified': verified,
      'complete': complete,
      'newToday': newToday,
    };
  }

  /// Export the whole roster as pretty JSON (used by the admin panel).
  Future<String> exportJson() async {
    final users = await getAllUsers();
    return const JsonEncoder.withIndent('  ')
        .convert(users.map((u) => u.toMap()).toList());
  }
}
