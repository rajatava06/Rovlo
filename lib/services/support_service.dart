import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';

/// One message in a support thread (text and/or one image).
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.threadUser,
    required this.fromSupport,
    required this.body,
    required this.createdAt,
    this.imageUrl,
    this.readAt,
  });

  final String id;
  final String threadUser;
  final bool fromSupport;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  factory SupportMessage.fromRow(Map<String, dynamic> r) => SupportMessage(
        id: r['id'] as String,
        threadUser: r['thread_user'] as String,
        fromSupport: r['from_support'] as bool? ?? false,
        body: (r['body'] as String?) ?? '',
        imageUrl: r['image_url'] as String?,
        createdAt:
            DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        readAt: DateTime.tryParse(r['read_at'] as String? ?? '')?.toLocal(),
      );
}

/// A row of the agent inbox: one customer + their latest message.
class SupportThread {
  const SupportThread({
    required this.userId,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.lastBody,
    required this.lastAt,
    required this.lastFromSupport,
    required this.unread,
  });

  final String userId;
  final String name;
  final String? email;
  final String? photoUrl;
  final String lastBody;
  final DateTime lastAt;
  final bool lastFromSupport;
  final int unread;

  factory SupportThread.fromRow(Map<String, dynamic> r) {
    final name = (r['name'] as String?)?.trim();
    final hasImage = ((r['last_image_url'] as String?) ?? '').isNotEmpty;
    final body = (r['last_body'] as String?) ?? '';
    return SupportThread(
      userId: r['thread_user'] as String,
      name: (name == null || name.isEmpty) ? ((r['email'] as String?) ?? 'Traveller') : name,
      email: r['email'] as String?,
      photoUrl: r['photo_url'] as String?,
      lastBody: body.isNotEmpty ? body : (hasImage ? '📷 Photo' : ''),
      lastAt: DateTime.tryParse(r['last_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      lastFromSupport: r['last_from_support'] as bool? ?? false,
      unread: (r['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Support chat: customers talk to "Rovlo Support"; agents (listed in the
/// `support_agents` table) see every thread and reply. Text and images only.
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  Future<bool> isAgent() async {
    try {
      return await Backend.client.rpc('is_support_agent') == true;
    } catch (_) {
      return false;
    }
  }

  // ── Customer side ───────────────────────────────────────────────────────────

  Future<List<SupportMessage>> myMessages() async {
    final uid = Backend.uid;
    if (uid == null) return const [];
    return threadMessages(uid);
  }

  Future<void> sendAsCustomer({String text = '', String? imageUrl}) async {
    final uid = Backend.uid;
    if (uid == null) throw StateError('Not signed in');
    await Backend.client.from('support_messages').insert({
      'thread_user': uid,
      'sender_id': uid,
      'from_support': false,
      'body': text,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    unawaited(_notify(preview: text.isNotEmpty ? text : '📷 Photo'));
  }

  Future<void> markMineRead() async {
    try {
      await Backend.client.rpc('mark_support_read');
    } catch (_) {}
  }

  // ── Agent side ──────────────────────────────────────────────────────────────

  Future<List<SupportThread>> threads() async {
    final rows = await Backend.client.rpc('support_threads');
    return (rows as List)
        .map((r) => SupportThread.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> sendAsAgent(String threadUser, {String text = '', String? imageUrl}) async {
    final uid = Backend.uid;
    if (uid == null) throw StateError('Not signed in');
    await Backend.client.from('support_messages').insert({
      'thread_user': threadUser,
      'sender_id': uid,
      'from_support': true,
      'body': text,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    unawaited(_notify(preview: text.isNotEmpty ? text : '📷 Photo', threadUser: threadUser));
  }

  Future<void> markThreadRead(String threadUser) async {
    try {
      await Backend.client.rpc('mark_support_read', params: {'p_thread': threadUser});
    } catch (_) {}
  }

  // ── Shared ──────────────────────────────────────────────────────────────────

  Future<List<SupportMessage>> threadMessages(String threadUser) async {
    final rows = await Backend.client
        .from('support_messages')
        .select()
        .eq('thread_user', threadUser)
        .order('created_at', ascending: false)
        .limit(300);
    return rows.reversed.map<SupportMessage>(SupportMessage.fromRow).toList();
  }

  /// Live inserts. [threadUser] limits it to one thread; null = everything the
  /// signed-in user is allowed to see (all threads for an agent).
  RealtimeChannel subscribe(String name, void Function(SupportMessage) onMessage,
      {String? threadUser}) {
    return Backend.client
        .channel(name)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_messages',
          filter: threadUser == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'thread_user',
                  value: threadUser,
                ),
          callback: (payload) {
            try {
              onMessage(SupportMessage.fromRow(payload.newRecord));
            } catch (e) {
              debugPrint('[SupportService] bad payload: $e');
            }
          },
        )
        .subscribe();
  }

  /// Push notification to the other side (best effort — the message itself is
  /// already stored).
  Future<void> _notify({required String preview, String? threadUser}) async {
    try {
      await Backend.client.functions.invoke('notify-support', body: {
        'preview': preview,
        if (threadUser != null) 'thread_user': threadUser,
      });
    } catch (e) {
      debugPrint('[SupportService] push not sent: $e');
    }
  }
}
