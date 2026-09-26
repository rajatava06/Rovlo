import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';

/// "typing…" for one conversation, sent over a Supabase Realtime **Broadcast**
/// channel (ephemeral — nothing is stored). Both people join the same channel
/// while the chat is open.
class TypingChannel {
  TypingChannel({required this.me, required this.peer}) {
    final ids = [me, peer]..sort();
    _channel = Backend.client
        .channel('rovlo-typing-${ids[0]}-${ids[1]}')
        .onBroadcast(event: 'typing', callback: _onTyping)
        .subscribe();
  }

  final String me;
  final String peer;

  static const Duration _resend = Duration(seconds: 2);
  static const Duration _expire = Duration(seconds: 5);

  late final RealtimeChannel _channel;
  final ValueNotifier<bool> peerTyping = ValueNotifier<bool>(false);

  Timer? _expireTimer;
  DateTime? _lastSent;
  bool _iAmTyping = false;
  bool _disposed = false;

  void _onTyping(Map<String, dynamic> raw) {
    if (_disposed) return;
    final data = raw['payload'] is Map
        ? Map<String, dynamic>.from(raw['payload'] as Map)
        : raw;
    if (data['from'] != peer) return;
    final typing = data['typing'] == true;
    peerTyping.value = typing;
    _expireTimer?.cancel();
    if (typing) {
      // If the "stopped" message is lost, don't stay stuck on "typing…".
      _expireTimer = Timer(_expire, () {
        if (!_disposed) peerTyping.value = false;
      });
    }
  }

  /// Call on every keystroke (throttled internally).
  void typing() {
    final now = DateTime.now();
    if (_iAmTyping && _lastSent != null && now.difference(_lastSent!) < _resend) {
      return;
    }
    _iAmTyping = true;
    _lastSent = now;
    _send(true);
  }

  /// Call when the field is cleared, the message is sent or the screen closes.
  void stopped() {
    if (!_iAmTyping) return;
    _iAmTyping = false;
    _lastSent = null;
    _send(false);
  }

  void _send(bool typing) {
    if (_disposed) return;
    unawaited(_channel
        .sendBroadcastMessage(
          event: 'typing',
          payload: {'from': me, 'typing': typing},
        )
        .catchError((Object e) {
      debugPrint('[Typing] send failed: $e');
      return ChannelResponse.timedOut;
    }));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    stopped();
    _disposed = true;
    _expireTimer?.cancel();
    peerTyping.dispose();
    try {
      await Backend.client.removeChannel(_channel);
    } catch (_) {}
  }
}
