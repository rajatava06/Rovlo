import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';

/// Who is online right now (the green dot).
///
/// Every signed-in device that has the app in the foreground joins one Supabase
/// Realtime **Presence** channel. Presence is maintained by the Realtime server
/// itself: when the app is closed, backgrounded, crashes or loses the network the
/// user disappears within seconds — nothing is written to the database, so there
/// is no "stuck online" state.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const String _channelName = 'rovlo-online';

  /// User ids that are online now (never contains me).
  final ValueNotifier<Set<String>> online = ValueNotifier<Set<String>>(const {});

  /// True while the app is in the foreground.
  final ValueNotifier<bool> foreground = ValueNotifier<bool>(true);

  RealtimeChannel? _channel;
  String? _uid;
  bool _observing = false;
  bool _tracking = false;

  bool isOnline(String userId) => online.value.contains(userId);

  /// Call with the signed-in user id (or null on sign-out).
  void bind(String? userId) {
    if (userId == _uid) return;
    _teardown();
    _uid = userId;
    if (userId == null || !Backend.ready) return;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    foreground.value =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    if (foreground.value) _join();
  }

  void _join() {
    final uid = _uid;
    if (uid == null || _channel != null) return;

    final channel = Backend.client.channel(
      _channelName,
      opts: RealtimeChannelConfig(key: uid),
    );
    channel
        .onPresenceSync((_) => _recompute(channel))
        .onPresenceJoin((_) => _recompute(channel))
        .onPresenceLeave((_) => _recompute(channel))
        .subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _track(channel);
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('[Presence] channel $status $error');
      }
    });
    _channel = channel;
  }

  Future<void> _track(RealtimeChannel channel) async {
    if (!foreground.value || _uid == null) return;
    try {
      await channel.track({
        'user_id': _uid,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
      _tracking = true;
    } catch (e) {
      debugPrint('[Presence] track failed: $e');
    }
  }

  void _recompute(RealtimeChannel channel) {
    final me = _uid;
    final next = <String>{
      for (final s in channel.presenceState())
        if (s.key != me) s.key,
    };
    if (!setEquals(next, online.value)) online.value = next;
  }

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    _tracking = false;
    if (channel == null) return;
    try {
      await channel.untrack();
    } catch (_) {}
    try {
      await Backend.client.removeChannel(channel);
    } catch (_) {}
    online.value = const {};
  }

  void _teardown() {
    unawaited(_leave());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        foreground.value = true;
        if (_channel == null) {
          _join();
        } else if (!_tracking) {
          unawaited(_track(_channel!));
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Leave right away so people see me go offline instead of waiting for
        // the OS to kill the connection.
        foreground.value = false;
        unawaited(_leave());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
