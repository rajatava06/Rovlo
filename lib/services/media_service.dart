import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';

/// Uploads images to Supabase Storage and returns their public URLs.
///
/// Buckets (created by schema.sql):
///   avatars     profile photos
///   chat-media  photos sent in chats
/// Files are stored under `<user-id>/<random>.<ext>`; storage policies only
/// allow users to write inside their own folder.
class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final Random _rng = Random.secure();

  static bool isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  String _randomName(String ext) {
    final r = List.generate(8, (_) => _rng.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$r.$ext';
  }

  /// Uploads a picked image. Throws if the upload fails — callers must never
  /// store a local file path in the database.
  Future<String> uploadXFile(XFile file, {String bucket = 'avatars'}) async {
    final uid = Backend.uid;
    if (uid == null) throw StateError('Not signed in');

    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final safeExt = const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext) ? ext : 'jpg';
    final mime = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    final bytes = await file.readAsBytes();
    final objectPath = '$uid/${_randomName(safeExt)}';
    await Backend.client.storage.from(bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: mime, cacheControl: '31536000'),
        );
    return Backend.client.storage.from(bucket).getPublicUrl(objectPath);
  }

  /// Uploads a local path (as produced by `image_picker`) unless it already is
  /// a URL.
  Future<String> ensureRemote(String pathOrUrl, {String bucket = 'avatars'}) async {
    if (isRemote(pathOrUrl)) return pathOrUrl;
    try {
      return await uploadXFile(XFile(pathOrUrl), bucket: bucket);
    } catch (e) {
      debugPrint('[MediaService] upload failed: $e');
      rethrow;
    }
  }

  Future<List<String>> ensureAllRemote(List<String> paths,
      {String bucket = 'avatars'}) async {
    final out = <String>[];
    for (final p in paths) {
      out.add(await ensureRemote(p, bucket: bucket));
    }
    return out;
  }
}
