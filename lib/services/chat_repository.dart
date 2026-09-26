import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/traveler.dart';

/// How I am connected to another person.
enum ChatLink {
  /// Nothing yet — I can send a request.
  none,

  /// I asked, they have not answered.
  sent,

  /// They asked me, I have not answered.
  received,

  /// Accepted — we can chat.
  connected,

  /// I asked and they declined (I can try again after 24 h).
  declined,
}

/// A chat request, from either side.
class ChatRequest {
  const ChatRequest({
    required this.id,
    required this.peerId,
    required this.name,
    required this.photoUrl,
    required this.isVerified,
    required this.age,
    required this.city,
    required this.incoming,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String peerId;
  final String name;
  final String photoUrl;
  final bool isVerified;
  final int age;
  final String city;

  /// True when *they* asked *me*.
  final bool incoming;

  /// pending | accepted | declined
  final String status;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  String get nameWithAge => age > 0 ? '$name, $age' : name;

  factory ChatRequest.fromRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?)?.trim();
    final display = (name == null || name.isEmpty) ? 'Traveller' : name;
    final photo = (r['photo_url'] as String?) ?? '';
    return ChatRequest(
      id: r['id'] as String,
      peerId: r['peer_id'] as String,
      name: display,
      photoUrl: photo.isNotEmpty ? photo : Traveler.avatarFallback(display),
      isVerified: r['is_verified'] as bool? ?? false,
      age: (r['age'] as num?)?.toInt() ?? 0,
      city: (r['city'] as String?) ?? '',
      incoming: r['direction'] == 'in',
      status: (r['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// A request-related failure with a message that is safe to show to the user.
class ChatRequestException implements Exception {
  ChatRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChatRepository {
  SupabaseClient get _db => Backend.client;

  Future<List<ChatRequest>> myRequests() async {
    final rows = await _db.rpc('my_chat_requests');
    return (rows as List)
        .map((r) => ChatRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Sends a chat request. Returns `pending`, or `accepted` when the other
  /// person had already asked me (then we are connected straight away).
  Future<String> send(String to) async {
    try {
      final res = await _db.rpc('send_chat_request', params: {'p_to': to});
      final status = res as String;
      unawaited(_push(status == 'accepted' ? 'accepted' : 'request', to));
      return status;
    } on PostgrestException catch (e) {
      throw ChatRequestException(_friendly(e));
    }
  }

  Future<void> respond(String from, {required bool accept}) async {
    try {
      await _db.rpc('respond_chat_request', params: {
        'p_from': from,
        'p_accept': accept,
      });
      if (accept) unawaited(_push('accepted', from));
    } on PostgrestException catch (e) {
      throw ChatRequestException(_friendly(e));
    }
  }

  Future<void> cancel(String to) async {
    try {
      await _db.rpc('cancel_chat_request', params: {'p_to': to});
    } on PostgrestException catch (e) {
      throw ChatRequestException(_friendly(e));
    }
  }

  /// Best-effort push notification (works when the app is closed).
  /// [type] = request | accepted | message.
  Future<void> _push(String type, String to) => pushNotify(type, to);

  static Future<void> pushNotify(String type, String to) async {
    try {
      await Backend.client.functions.invoke('notify-chat', body: {
        'type': type,
        'to': to,
      });
    } catch (e) {
      debugPrint('[ChatRepository] push "$type" not sent: $e');
    }
  }

  String _friendly(PostgrestException e) {
    final m = e.message;
    if (m.contains('declined_recently')) {
      return 'They declined your request recently. You can try again in a day.';
    }
    if (m.contains('too_many_pending')) {
      return 'You have too many pending requests. Wait for some to be answered.';
    }
    if (m.contains('no pending request')) {
      return 'That request is no longer available.';
    }
    if (m.contains('user not found')) return 'This traveler is no longer available.';
    if (m.contains('blocked')) return 'Your account cannot send requests.';
    if (m.contains('send_chat_request') ||
        m.contains('my_chat_requests') ||
        e.code == 'PGRST202' ||
        e.code == '42883') {
      return 'Chat requests are not set up on the server yet '
          '(run supabase/schema.sql).';
    }
    return 'Could not do that. Check your connection and try again.';
  }
}
