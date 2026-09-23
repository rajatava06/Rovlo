import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/traveler.dart';

enum SwipeKind { like, pass, save }

/// A mutual match (both users liked each other).
class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.isVerified,
    required this.matchedAt,
  });

  final String id;
  final String name;
  final String photoUrl;
  final bool isVerified;
  final DateTime matchedAt;

  factory MatchSummary.fromRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?)?.trim();
    final display = (name == null || name.isEmpty) ? 'Traveller' : name;
    final photo = (r['photo_url'] as String?) ?? '';
    return MatchSummary(
      id: r['id'] as String,
      name: display,
      photoUrl: photo.isNotEmpty ? photo : Traveler.avatarFallback(display),
      isVerified: r['is_verified'] as bool? ?? false,
      matchedAt: DateTime.tryParse(r['matched_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Somebody who liked me (waiting for my answer) or somebody I liked (waiting
/// for theirs).
class LikeRequest {
  const LikeRequest({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.isVerified,
    required this.age,
    required this.city,
    required this.likedAt,
  });

  final String id;
  final String name;
  final String photoUrl;
  final bool isVerified;
  final int age;
  final String city;
  final DateTime likedAt;

  String get nameWithAge => age > 0 ? '$name, $age' : name;

  factory LikeRequest.fromRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?)?.trim();
    final display = (name == null || name.isEmpty) ? 'Traveller' : name;
    final photo = (r['photo_url'] as String?) ?? '';
    return LikeRequest(
      id: r['id'] as String,
      name: display,
      photoUrl: photo.isNotEmpty ? photo : Traveler.avatarFallback(display),
      isVerified: r['is_verified'] as bool? ?? false,
      age: (r['age'] as num?)?.toInt() ?? 0,
      city: (r['city'] as String?) ?? '',
      likedAt: DateTime.tryParse(r['liked_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Everything about *other* travellers: discover feed, map pins, likes, saves.
/// All queries go through database functions that only return the public,
/// privacy-safe slice of a profile.
class TravelerRepository {
  SupabaseClient get _db => Backend.client;

  List<Traveler> _travelers(dynamic rows) => (rows as List)
      .map((r) => Traveler.fromRow(Map<String, dynamic>.from(r as Map)))
      .toList();

  /// Travellers I have not swiped on yet — closest first. When [destination]
  /// is given, only people going to / living in that place.
  Future<List<Traveler>> discover({String? destination, int limit = 50}) async {
    final rows = await _db.rpc('discover_travelers', params: {
      'p_destination': destination,
      'p_limit': limit,
    });
    return _travelers(rows);
  }

  /// Travellers currently visible on the map around a point.
  Future<List<Traveler>> nearby(double lat, double lng,
      {double radiusKm = 25}) async {
    final rows = await _db.rpc('nearby_travelers', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
    });
    return _travelers(rows);
  }

  Future<List<Traveler>> saved() async {
    final rows = await _db.rpc('my_saved_travelers');
    return _travelers(rows);
  }

  Future<List<MatchSummary>> matches() async {
    final rows = await _db.rpc('my_matches');
    return (rows as List)
        .map((r) => MatchSummary.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// People who liked me and are waiting for my answer.
  Future<List<LikeRequest>> likesReceived() async {
    final rows = await _db.rpc('my_likes_received');
    return (rows as List)
        .map((r) => LikeRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// People I liked who have not answered yet.
  Future<List<LikeRequest>> likesSent() async {
    final rows = await _db.rpc('my_likes_sent');
    return (rows as List)
        .map((r) => LikeRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Records a like / pass / save. Returns true when the like created a match.
  /// A like also sends the other person a push notification (best effort).
  Future<bool> swipe(String travelerId, SwipeKind kind) async {
    final res = await _db.rpc('record_swipe', params: {
      'p_to': travelerId,
      'p_kind': kind.name,
    });
    if (kind == SwipeKind.like) unawaited(_notifyLike(travelerId));
    return res == true;
  }

  Future<void> _notifyLike(String to) async {
    try {
      await _db.functions.invoke('notify-like', body: {'to': to});
    } catch (e) {
      debugPrint('[TravelerRepository] like push not sent: $e');
    }
  }

  /// "Save this trip": stores the trip and shows it on my profile.
  Future<void> saveTrip({
    required String destination,
    required String week,
    required String month,
    required String year,
  }) async {
    final uid = Backend.uid;
    if (uid == null) return;
    await _db.from('trips').insert({
      'user_id': uid,
      'destination': destination,
      'travel_week': week,
      'travel_month': month,
      'travel_year': year,
    });
    await _db.from('profiles').update({
      'trip_destination': destination,
      'trip_dates': '$week, $month $year',
    }).eq('id', uid);
  }
}
