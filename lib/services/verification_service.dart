import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';

enum VerificationState { none, pending, approved, rejected }

class VerificationStatus {
  const VerificationStatus(this.state, {this.note});
  final VerificationState state;

  /// Reason given by the admin when a request was rejected.
  final String? note;
}

/// One request waiting in the admin queue.
class VerificationRequest {
  const VerificationRequest({
    required this.userId,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.profilePhotos,
    required this.frontPath,
    required this.posePath,
    required this.challenge,
    required this.createdAt,
  });

  final String userId;
  final String name;
  final String? email;
  final String? photoUrl;

  /// The person's profile photos, to compare the selfies against.
  final List<String> profilePhotos;

  /// Straight-on selfie.
  final String frontPath;

  /// Selfie doing the random pose that was asked for.
  final String posePath;
  final String challenge;
  final DateTime createdAt;

  factory VerificationRequest.fromRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?)?.trim();
    return VerificationRequest(
      userId: r['user_id'] as String,
      name: (name == null || name.isEmpty) ? ((r['email'] as String?) ?? 'Traveller') : name,
      email: r['email'] as String?,
      photoUrl: r['photo_url'] as String?,
      profilePhotos: [
        for (final p in (r['profile_photos'] as List? ?? const []))
          if (p is String && p.isNotEmpty) p,
      ],
      frontPath: (r['front_path'] as String?) ?? '',
      posePath: (r['pose_path'] as String?) ?? '',
      challenge: (r['challenge'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class VerificationException implements Exception {
  VerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Photo verification: the user sends a straight-on selfie and a selfie doing a
/// random pose, an admin compares them with the profile photos and approves or
/// rejects. Approval is the only way to get the blue tick. No ID document is
/// collected. The photos live in a private bucket and are deleted right after
/// the review.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  static const String _bucket = 'verification-docs';
  final Random _rng = Random.secure();

  SupabaseClient get _db => Backend.client;

  // ── User ────────────────────────────────────────────────────────────────────

  Future<VerificationStatus> myStatus() async {
    final uid = Backend.uid;
    if (uid == null) return const VerificationStatus(VerificationState.none);
    final row = await _db
        .from('verification_requests')
        .select('status, note')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return const VerificationStatus(VerificationState.none);
    return VerificationStatus(
      switch (row['status']) {
        'pending' => VerificationState.pending,
        'approved' => VerificationState.approved,
        'rejected' => VerificationState.rejected,
        _ => VerificationState.none,
      },
      note: row['note'] as String?,
    );
  }

  String _name(String kind) {
    final r = List.generate(10, (_) => _rng.nextInt(36).toRadixString(36)).join();
    return '${Backend.uid}/${kind}_${DateTime.now().millisecondsSinceEpoch}_$r.jpg';
  }

  /// Uploads both photos and files the request. Throws
  /// [VerificationException] with a readable message.
  Future<void> submit({
    required Uint8List frontPhoto,
    required Uint8List posePhoto,
    required String challenge,
  }) async {
    if (Backend.uid == null) throw VerificationException('Please sign in again.');
    final idPath = _name('front');
    final facePath = _name('pose');
    try {
      final storage = _db.storage.from(_bucket);
      const opts = FileOptions(contentType: 'image/jpeg', upsert: false);
      await storage.uploadBinary(idPath, frontPhoto, fileOptions: opts);
      await storage.uploadBinary(facePath, posePhoto, fileOptions: opts);
      await _db.rpc('submit_verification', params: {
        'p_front_path': idPath,
        'p_pose_path': facePath,
        'p_challenge': challenge,
      });
    } on PostgrestException catch (e) {
      unawaited(_cleanup([idPath, facePath]));
      if (e.message.contains('already_pending')) {
        throw VerificationException('You already have a request under review.');
      }
      if (e.message.contains('already_verified')) {
        throw VerificationException('You are already verified.');
      }
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw VerificationException(
            'Verification is not set up on the server yet (run supabase/schema.sql).');
      }
      throw VerificationException('Could not send your request. Please try again.');
    } catch (e) {
      debugPrint('[Verification] submit failed: $e');
      unawaited(_cleanup([idPath, facePath]));
      throw VerificationException(
          'Upload failed. Check your connection and try again.');
    }
  }

  Future<void> _cleanup(List<String> paths) async {
    try {
      await _db.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  /// Tells the app when an admin decides (so the tick appears without a restart).
  RealtimeChannel? watchMine(void Function(VerificationStatus status) onChange) {
    final uid = Backend.uid;
    if (uid == null || !Backend.ready) return null;
    return _db
        .channel('rovlo-verification-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'verification_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            onChange(VerificationStatus(
              switch (row['status']) {
                'approved' => VerificationState.approved,
                'rejected' => VerificationState.rejected,
                _ => VerificationState.pending,
              },
              note: row['note'] as String?,
            ));
          },
        )
        .subscribe();
  }

  // ── Admin ───────────────────────────────────────────────────────────────────

  Future<List<VerificationRequest>> queue() async {
    final rows = await _db.rpc('admin_verification_queue');
    return (rows as List)
        .map((r) => VerificationRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Short-lived link to look at one of the private photos.
  Future<String> signedUrl(String path) =>
      _db.storage.from(_bucket).createSignedUrl(path, 300);

  /// Approve (gives the tick) or reject, then delete the photos.
  Future<void> review(String userId, {required bool approve, String? note}) async {
    try {
      final res = await _db.rpc('admin_review_verification', params: {
        'p_user': userId,
        'p_approve': approve,
        'p_note': note,
      });
      final paths = <String>[
        for (final r in (res as List))
          for (final k in const ['doc_path', 'face_path'])
            if ((r as Map)[k] is String && (r[k] as String).isNotEmpty) r[k] as String,
      ];
      if (paths.isNotEmpty) unawaited(_cleanup(paths));
    } on PostgrestException catch (e) {
      if (e.message.contains('no pending request')) {
        throw VerificationException('This request was already handled.');
      }
      if (e.message.contains('forbidden')) {
        throw VerificationException('Only admins can review verifications.');
      }
      throw VerificationException('Could not save the decision. Try again.');
    }
  }
}
