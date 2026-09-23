import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/app_user.dart';
import '../models/traveler.dart';
import '../services/support_service.dart';
import '../services/traveler_repository.dart';

/// Id used for the built-in Rovlo assistant conversation.
const String kBotId = 'rovlo-bot';

/// Id of the real "Rovlo Support" conversation (answered by the support team).
const String kSupportId = 'rovlo-support';

class ChatMessage {
  ChatMessage({
    this.id,
    required this.text,
    this.imageUrl,
    required this.isMe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String? id;
  final String text;
  final String? imageUrl;
  final bool isMe;
  final DateTime timestamp;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get timeFormatted {
    final hr = timestamp.hour;
    final min = timestamp.minute.toString().padLeft(2, '0');
    final period = hr >= 12 ? 'PM' : 'AM';
    final displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
    return '$displayHr:$min $period';
  }
}

class ChatConversation {
  ChatConversation({
    required this.peerId,
    required this.contactName,
    required this.contactImageUrl,
    required this.isVerified,
    List<ChatMessage>? messages,
    this.hasUnread = false,
    this.isBot = false,
    this.isSupport = false,
    this.lastPreview,
    this.lastAt,
  }) : messages = messages ?? [];

  final String peerId;
  final String contactName;
  final String contactImageUrl;
  final bool isVerified;
  final List<ChatMessage> messages;
  bool hasUnread;
  final bool isBot;
  final bool isSupport;
  bool loaded = false;

  /// Preview of the newest message when the full history is not loaded yet.
  String? lastPreview;
  DateTime? lastAt;

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
  String get previewText => lastMessage?.text ?? lastPreview ?? 'Say hi 👋';
  String get timeText => lastMessage?.timeFormatted ?? '';
  DateTime? get sortTime => lastMessage?.timestamp ?? lastAt;
}

/// Chats are stored in Supabase (`messages`) and arrive live over Realtime.
/// Only people I have matched with can be messaged (enforced by the database).
/// The Rovlo assistant is a local, in-memory conversation.
class ChatProvider extends ChangeNotifier {
  ChatProvider() {
    _conversations
      ..add(_makeBot())
      ..add(_makeSupport());
  }

  final TravelerRepository _travelers = TravelerRepository();
  final List<ChatConversation> _conversations = [];
  List<MatchSummary> _matches = [];
  List<LikeRequest> _received = [];
  List<LikeRequest> _sent = [];
  RealtimeChannel? _likesChannel;
  final StreamController<String> _notificationStreamController =
      StreamController<String>.broadcast();

  RealtimeChannel? _channel;
  RealtimeChannel? _supportChannel;
  String? _userId;
  bool _isAgent = false;
  final StreamController<SupportMessage> _supportEvents =
      StreamController<SupportMessage>.broadcast();

  /// Every new support message this user may see (agents: all customers).
  Stream<SupportMessage> get supportStream => _supportEvents.stream;
  bool loading = false;

  List<ChatConversation> get conversations => _conversations;
  List<MatchSummary> get matches => _matches;

  /// People who liked me — I decide whether to accept.
  List<LikeRequest> get requests => _received;

  /// People I liked who have not answered yet.
  List<LikeRequest> get pending => _sent;
  Stream<String> get notificationStream => _notificationStreamController.stream;

  /// Matches I have not started a conversation with yet.
  List<MatchSummary> get newMatches => _matches
      .where((m) => _conversations.every((c) => c.peerId != m.id))
      .toList();

  bool get hasUnreadMessages =>
      _conversations.any((c) => c.hasUnread) || _received.isNotEmpty;

  ChatConversation _makeBot() => ChatConversation(
        peerId: kBotId,
        contactName: 'Rovlo',
        contactImageUrl: '',
        isVerified: true,
        isBot: true,
        hasUnread: true,
        messages: [
          ChatMessage(
            text:
                'Hello! I am Rovlo, your intelligent travel companion. 🌍 Ask me anything about travel trips, destinations, safety, or profile setup!',
            isMe: false,
          ),
        ],
      );

  ChatConversation _makeSupport() => ChatConversation(
        peerId: kSupportId,
        contactName: 'Rovlo Support',
        contactImageUrl: '',
        isVerified: true,
        isSupport: true,
      );

  // ── Session binding ─────────────────────────────────────────────────────────

  /// Called whenever the signed-in user changes (see ProxyProvider in main.dart).
  void bindUser(String? userId, {bool isAgent = false}) {
    if (userId == _userId && isAgent == _isAgent) return;
    _userId = userId;
    _isAgent = isAgent;
    _channel?.unsubscribe();
    _channel = null;
    _supportChannel?.unsubscribe();
    _supportChannel = null;
    _likesChannel?.unsubscribe();
    _likesChannel = null;
    _conversations
      ..clear()
      ..add(_makeBot())
      ..add(_makeSupport());
    _matches = [];
    _received = [];
    _sent = [];
    notifyListeners();
    if (userId != null && Backend.ready) {
      refresh();
      _subscribe(userId);
      _subscribeSupport(userId);
      _subscribeLikes(userId);
    }
  }

  Future<void> refresh() async {
    final me = _userId;
    if (me == null || !Backend.ready) return;
    loading = true;
    notifyListeners();
    try {
      unawaited(_loadSupport());
      final matchesFuture = _travelers.matches();
      final receivedFuture = _travelers.likesReceived();
      final sentFuture = _travelers.likesSent();
      final convRows = await Backend.client.rpc('my_conversations') as List;
      _matches = await matchesFuture;
      _received = await receivedFuture;
      _sent = await sentFuture;

      for (final raw in convRows) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['peer_id'] as String;
        final name = (r['peer_name'] as String?)?.trim();
        final display = (name == null || name.isEmpty) ? 'Traveller' : name;
        final photo = (r['peer_photo'] as String?) ?? '';
        final existing = _find(id);
        final body = (r['last_body'] as String?) ?? '';
        final hasImage = ((r['last_image_url'] as String?) ?? '').isNotEmpty;
        final preview = body.isNotEmpty ? body : (hasImage ? '📷 Photo' : '');
        final at = DateTime.tryParse(r['last_at'] as String? ?? '')?.toLocal();
        final unread = ((r['unread_count'] as num?) ?? 0) > 0;

        if (existing != null) {
          existing.lastPreview = preview;
          existing.lastAt = at;
          existing.hasUnread = unread;
        } else {
          _conversations.add(ChatConversation(
            peerId: id,
            contactName: display,
            contactImageUrl: photo.isNotEmpty ? photo : Traveler.avatarFallback(display),
            isVerified: r['peer_verified'] as bool? ?? false,
            lastPreview: preview,
            lastAt: at,
            hasUnread: unread,
          ));
        }
      }
      _sort();
    } catch (e) {
      debugPrint('[ChatProvider] refresh failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Like requests ───────────────────────────────────────────────────────────

  /// Call after I like somebody so they show up as "Pending" right away.
  Future<void> onLiked() => _refreshLikes();

  Future<void> _refreshLikes() async {
    if (_userId == null || !Backend.ready) return;
    try {
      final r = await Future.wait<Object>([
        _travelers.matches(),
        _travelers.likesReceived(),
        _travelers.likesSent(),
      ]);
      _matches = r[0] as List<MatchSummary>;
      _received = r[1] as List<LikeRequest>;
      _sent = r[2] as List<LikeRequest>;
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] likes refresh failed: $e');
    }
  }

  void _subscribeLikes(String me) {
    // RLS lets me see likes addressed to me (never passes / saves).
    _likesChannel = Backend.client
        .channel('rovlo-likes-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user',
            value: me,
          ),
          callback: (payload) => _onIncomingLike(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onIncomingLike(Map<String, dynamic> row) async {
    if (row['kind'] != 'like') return;
    final from = row['from_user'] as String?;
    await _refreshLikes();
    if (from == null) return;
    final matched = _matches.where((m) => m.id == from).toList();
    if (matched.isNotEmpty) {
      _notificationStreamController.add("It's a match with ${matched.first.name}! 🎉");
      return;
    }
    final req = _received.where((r) => r.id == from).toList();
    final who = req.isNotEmpty ? req.first.name : 'Someone';
    _notificationStreamController.add('$who liked you 💙 Open Chats to accept.');
  }

  /// Accepts a like (= like them back). True when it opened a chat.
  Future<bool> acceptRequest(String travelerId) async {
    final match = await _travelers.swipe(travelerId, SwipeKind.like);
    await _refreshLikes();
    return match;
  }

  /// Declines a like; they disappear from my requests.
  Future<void> declineRequest(String travelerId) async {
    await _travelers.swipe(travelerId, SwipeKind.pass);
    await _refreshLikes();
  }

  // ── Support conversation ────────────────────────────────────────────────────

  ChatMessage _fromSupport(SupportMessage m) => ChatMessage(
        id: m.id,
        text: m.body,
        imageUrl: m.imageUrl,
        isMe: !m.fromSupport,
        timestamp: m.createdAt,
      );

  Future<void> _loadSupport() async {
    final conv = _find(kSupportId);
    if (conv == null || !Backend.ready) return;
    try {
      final list = await SupportService.instance.myMessages();
      conv.messages
        ..clear()
        ..addAll(list.map(_fromSupport));
      conv.loaded = true;
      conv.hasUnread = list.any((m) => m.fromSupport && m.readAt == null);
      if (list.isNotEmpty) conv.lastAt = list.last.createdAt;
      _sort();
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] support load failed: $e');
    }
  }

  void _subscribeSupport(String me) {
    // Agents watch every thread; everybody else only their own.
    _supportChannel = SupportService.instance.subscribe(
      'rovlo-support-$me',
      (m) => _onSupportMessage(m, me),
      threadUser: _isAgent ? null : me,
    );
  }

  void _onSupportMessage(SupportMessage m, String me) {
    _supportEvents.add(m);
    if (m.threadUser != me) {
      // An agent is looking at somebody else's thread.
      if (!m.fromSupport) {
        _notificationStreamController.add(
          'Support: ${m.body.isNotEmpty ? m.body : '📷 Photo'}',
        );
      }
      return;
    }
    final conv = _find(kSupportId);
    if (conv == null) return;
    // My own messages were already added when I sent them.
    if (!m.fromSupport) return;
    if (conv.messages.any((x) => x.id == m.id)) return;
    conv.messages.add(_fromSupport(m));
    conv.lastAt = m.createdAt;
    if (m.fromSupport) {
      conv.hasUnread = true;
      _notificationStreamController.add(
        'Rovlo Support: ${m.body.isNotEmpty ? m.body : '📷 Photo'}',
      );
    }
    _sort();
    notifyListeners();
  }

  void _sort() {
    _conversations.sort((a, b) {
      if (a.isBot != b.isBot) return a.isBot ? -1 : 1;
      if (a.isSupport != b.isSupport) return a.isSupport ? -1 : 1;
      final at = a.sortTime;
      final bt = b.sortTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
  }

  void _subscribe(String me) {
    _channel = Backend.client
        .channel('rovlo-messages-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: me,
          ),
          callback: (payload) => _onIncoming(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onIncoming(Map<String, dynamic> row) async {
    final from = row['sender_id'] as String;
    var conv = _find(from);
    if (conv == null) {
      // New person wrote to me — pull their card via the conversation list.
      await refresh();
      conv = _find(from);
      if (conv == null) return;
    }
    final msg = _fromRow(row);
    if (conv.loaded && !conv.messages.any((m) => m.id == msg.id)) {
      conv.messages.add(msg);
    }
    conv.lastPreview = msg.text.isNotEmpty ? msg.text : '📷 Photo';
    conv.lastAt = msg.timestamp;
    conv.hasUnread = true;
    _sort();
    notifyListeners();
    _notificationStreamController
        .add('${conv.contactName}: ${msg.text.isNotEmpty ? msg.text : '📷 Photo'}');
  }

  ChatMessage _fromRow(Map<String, dynamic> r) => ChatMessage(
        id: r['id'] as String?,
        text: (r['body'] as String?) ?? '',
        imageUrl: r['image_url'] as String?,
        isMe: r['sender_id'] == _userId,
        timestamp: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal(),
      );

  // ── Lookup ──────────────────────────────────────────────────────────────────

  ChatConversation? _find(String peerId) {
    for (final c in _conversations) {
      if (c.peerId == peerId) return c;
    }
    return null;
  }

  ChatConversation? getConversation(String peerId) => _find(peerId);

  /// Returns the conversation with [peer], creating an empty one for a match.
  ChatConversation ensureConversation({
    required String peerId,
    required String name,
    required String imageUrl,
    required bool isVerified,
  }) {
    final existing = _find(peerId);
    if (existing != null) return existing;
    final conv = ChatConversation(
      peerId: peerId,
      contactName: name,
      contactImageUrl: imageUrl,
      isVerified: isVerified,
    )..loaded = true;
    _conversations.add(conv);
    _sort();
    notifyListeners();
    return conv;
  }

  // ── History / read state ────────────────────────────────────────────────────

  Future<void> loadMessages(String peerId) async {
    final conv = _find(peerId);
    final me = _userId;
    if (conv == null || conv.isBot || me == null || conv.loaded) return;
    if (conv.isSupport) {
      await _loadSupport();
      return;
    }
    try {
      final rows = await Backend.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$me,recipient_id.eq.$peerId),and(sender_id.eq.$peerId,recipient_id.eq.$me)')
          .order('created_at', ascending: false)
          .limit(200);
      conv.messages
        ..clear()
        ..addAll(rows.reversed.map<ChatMessage>(_fromRow));
      conv.loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] loadMessages failed: $e');
    }
  }

  Future<void> markAsRead(String peerId) async {
    final conv = _find(peerId);
    if (conv == null || !conv.hasUnread) return;
    conv.hasUnread = false;
    notifyListeners();
    if (conv.isBot || !Backend.ready) return;
    if (conv.isSupport) {
      await SupportService.instance.markMineRead();
      return;
    }
    try {
      await Backend.client.rpc('mark_conversation_read', params: {'p_peer': peerId});
    } catch (_) {}
  }

  // ── Sending ─────────────────────────────────────────────────────────────────

  /// Throws if a message to a real user could not be stored.
  Future<void> sendMessage(
    String peerId,
    String text,
    AppUser? currentUser, {
    String? imageUrl,
  }) async {
    final conv = _find(peerId);
    if (conv == null) return;

    final msg = ChatMessage(text: text, imageUrl: imageUrl, isMe: true);
    conv.messages.add(msg);
    conv.lastAt = msg.timestamp;
    _sort();
    notifyListeners();

    if (conv.isBot) {
      await _handleBotReply(conv, text, currentUser);
      return;
    }

    try {
      if (conv.isSupport) {
        await SupportService.instance.sendAsCustomer(
          text: text == '📷 Photo' && imageUrl != null ? '' : text,
          imageUrl: imageUrl,
        );
        return;
      }
      await Backend.client.from('messages').insert({
        'sender_id': _userId,
        'recipient_id': peerId,
        'body': text == '📷 Photo' && imageUrl != null ? '' : text,
        if (imageUrl != null) 'image_url': imageUrl,
      });
    } catch (e) {
      conv.messages.remove(msg);
      notifyListeners();
      rethrow;
    }
  }

  // ── Rovlo assistant (local) ─────────────────────────────────────────────────

  Future<void> _handleBotReply(
    ChatConversation conv,
    String userText,
    AppUser? currentUser,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final query = userText.toLowerCase();

    String reply;
    if (query.contains('photo') || query.contains('picture') || query.contains('image')) {
      reply = 'That looks amazing! 📸 Photos tell the best travel stories. Keep capturing those memories!';
    } else if (query.contains('hi') || query.contains('hello') || query.contains('hey')) {
      final nameStr = currentUser?.displayName ?? 'Traveler';
      reply =
          'Greetings, $nameStr! 👋 How can I assist with your journey today? Ask me about destinations, profile completion, or safety tips!';
    } else if (query.contains('profile') || query.contains('complete')) {
      final percent = currentUser != null
          ? (currentUser.profileCompletionPercent * 100).round()
          : 0;
      reply =
          '📋 Profile Completion: Your profile is currently $percent% complete.\n\nMake sure to add your DOB, travel interests, and photos for the best matches!';
    } else {
      reply =
          'Rovlo Bot here! 🤖 I\'m here to help you wander more and worry less. Need tips for packing, itinerary planning, or finding nearby travelers?';
    }

    conv.messages.add(ChatMessage(text: reply, isMe: false));
    conv.hasUnread = true;
    notifyListeners();
    _notificationStreamController.add('Rovlo: $reply');
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _supportChannel?.unsubscribe();
    _likesChannel?.unsubscribe();
    _supportEvents.close();
    _notificationStreamController.close();
    super.dispose();
  }
}
