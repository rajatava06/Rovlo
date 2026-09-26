import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend.dart';
import '../models/app_user.dart';
import '../models/traveler.dart';
import '../services/chat_repository.dart';
import '../services/e2ee_service.dart';
import '../services/presence_service.dart';
import '../services/support_service.dart';
import '../services/traveler_repository.dart';

/// Id used for the built-in Rovlo assistant conversation.
const String kBotId = 'rovlo-bot';

/// Id of the real "Rovlo Support" conversation (answered by the support team).
const String kSupportId = 'rovlo-support';

/// A location sent in a chat. It travels as an ordinary (end-to-end encrypted)
/// text message in the form `rovlo-loc:<lat>,<lng>`.
class SharedLocation {
  const SharedLocation(this.lat, this.lng);
  final double lat;
  final double lng;

  static final RegExp _pattern =
      RegExp(r'^rovlo-loc:(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)$');

  static String encode(double lat, double lng) =>
      'rovlo-loc:${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  static SharedLocation? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
    return SharedLocation(lat, lng);
  }

  /// What the chat list shows instead of the raw coordinates.
  static String previewFor(String text) =>
      tryParse(text) != null ? '📍 Location' : text;
}

/// Where a message I sent has got to.
enum MessageStatus {
  /// Still being encrypted / uploaded (clock icon).
  sending,

  /// Stored on the server (one grey tick).
  sent,

  /// Reached the other person's phone (two grey ticks).
  delivered,

  /// The other person opened the chat (two blue ticks).
  read,
}

class ChatMessage {
  ChatMessage({
    this.id,
    required this.text,
    this.imageUrl,
    required this.isMe,
    DateTime? timestamp,
    this.status = MessageStatus.sent,
    this.senderPub,
    this.recipientPub,
    this.undecryptable = false,
  }) : timestamp = timestamp ?? DateTime.now();

  String? id;
  final String text;

  /// A normal URL, or `e2ee:<path>` for an encrypted photo.
  final String? imageUrl;
  final bool isMe;
  DateTime timestamp;
  MessageStatus status;

  /// Public keys this message was sealed with (null for bot / support / old
  /// plaintext messages).
  final String? senderPub;
  final String? recipientPub;

  /// True when the message could not be decrypted on this phone.
  final bool undecryptable;

  /// Non-null when this message is a shared location.
  SharedLocation? get location => SharedLocation.tryParse(text);

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasEncryptedImage => E2eeService.isEncryptedImage(imageUrl);

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
  bool loading = false;
  bool needsReload = false;

  /// Preview of the newest message when the full history is not loaded yet.
  String? lastPreview;
  DateTime? lastAt;

  bool get isPeer => !isBot && !isSupport;

  /// True once a message has been exchanged (or a preview is known).
  bool get hasHistory => messages.isNotEmpty || (lastPreview?.isNotEmpty ?? false);

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
  String get previewText {
    final m = lastMessage;
    if (m != null) return _previewOf(m);
    return lastPreview ?? 'Say hi 👋';
  }

  String get timeText {
    final m = lastMessage;
    if (m != null) return m.timeFormatted;
    final at = lastAt;
    if (at == null) return '';
    return ChatMessage(text: '', isMe: false, timestamp: at).timeFormatted;
  }

  DateTime? get sortTime => lastMessage?.timestamp ?? lastAt;

  static String _previewOf(ChatMessage m) {
    if (m.undecryptable) return '🔒 Message unavailable';
    if (m.text.isNotEmpty) return SharedLocation.previewFor(m.text);
    return m.hasImage ? '📷 Photo' : '';
  }
}

/// Chats live in Supabase (`messages`) and arrive over Realtime.
///
/// * Messages between people are **end-to-end encrypted** on the device
///   ([E2eeService]); the database only stores ciphertext.
/// * You can only message people who accepted your **chat request** (or an older
///   mutual like) — enforced by the database, not only the app.
/// * Ticks: sending → sent → delivered → read, updated live.
/// * The Rovlo assistant and Rovlo Support are separate, non-encrypted threads
///   (support staff must be able to read them).
class ChatProvider extends ChangeNotifier {
  ChatProvider() {
    _conversations
      ..add(_makeBot())
      ..add(_makeSupport());
    PresenceService.instance.foreground.addListener(_onForegroundChanged);
  }

  final TravelerRepository _travelers = TravelerRepository();
  final ChatRepository _repo = ChatRepository();
  final E2eeService _e2ee = E2eeService.instance;

  final List<ChatConversation> _conversations = [];
  List<MatchSummary> _matches = [];
  List<LikeRequest> _received = [];
  List<LikeRequest> _sent = [];
  List<ChatRequest> _chatRequests = [];

  RealtimeChannel? _likesChannel;
  RealtimeChannel? _channel;
  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _supportChannel;

  final StreamController<String> _notificationStreamController =
      StreamController<String>.broadcast();
  final StreamController<ChatRequest> _incomingRequestController =
      StreamController<ChatRequest>.broadcast();
  final Set<String> _announcedRequests = {};
  final StreamController<LikeRequest> _incomingLikeController =
      StreamController<LikeRequest>.broadcast();
  final Set<String> _announcedLikes = {};
  final Map<String, Future<Uint8List>> _photoCache = {};

  /// Photos I am still uploading, shown from memory in the meantime.
  final Map<ChatMessage, Uint8List> _pendingPhotos = {};

  String? _userId;
  String? _activePeer;
  bool _isAgent = false;
  bool _disposed = false;
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

  /// Somebody just asked to chat with me (in-app banner with Accept / Decline).
  Stream<ChatRequest> get incomingRequestStream => _incomingRequestController.stream;

  /// Somebody liked my profile: banner with Accept / Decline.
  Stream<LikeRequest> get incomingLikeStream => _incomingLikeController.stream;

  /// Chat requests waiting for my answer.
  List<ChatRequest> get incomingChatRequests =>
      _chatRequests.where((r) => r.incoming && r.isPending).toList();

  /// Chat requests I sent that have not been answered.
  List<ChatRequest> get outgoingChatRequests =>
      _chatRequests.where((r) => !r.incoming && r.isPending).toList();

  /// Everybody I am allowed to chat with: accepted chat requests + mutual likes.
  List<MatchSummary> get _connections {
    final out = <MatchSummary>[
      for (final r in _chatRequests)
        if (r.isAccepted)
          MatchSummary(
            id: r.peerId,
            name: r.name,
            photoUrl: r.photoUrl,
            isVerified: r.isVerified,
            matchedAt: r.createdAt,
          ),
      ..._matches,
    ];
    final seen = <String>{};
    return out.where((m) => seen.add(m.id)).toList();
  }

  /// People I can chat with but have not exchanged a message with yet (the
  /// "new chat" bubbles at the top of the Chats tab).
  List<MatchSummary> get newMatches => _connections.where((m) {
        final c = _find(m.id);
        return c == null || !c.hasHistory;
      }).toList();

  /// Makes sure every connection has a row in the Messages list, so a chat is
  /// visible to both people as soon as it is accepted — not only after the
  /// first message.
  void _syncConnections() {
    for (final m in _connections) {
      if (_find(m.id) != null) continue;
      _conversations.add(ChatConversation(
        peerId: m.id,
        contactName: m.name,
        contactImageUrl: m.photoUrl,
        isVerified: m.isVerified,
        lastAt: m.matchedAt,
      ));
    }
    _sort();
  }

  bool get hasUnreadMessages =>
      _conversations.any((c) => c.hasUnread) ||
      _received.isNotEmpty ||
      incomingChatRequests.isNotEmpty;

  String? get activePeerId => _activePeer;

  /// How I am connected to [peerId] (drives the map card / profile buttons).
  ChatLink linkWith(String peerId) {
    if (_matches.any((m) => m.id == peerId)) return ChatLink.connected;
    for (final r in _chatRequests) {
      if (r.peerId != peerId) continue;
      if (r.isAccepted) return ChatLink.connected;
      if (r.isDeclined) return ChatLink.declined;
      return r.incoming ? ChatLink.received : ChatLink.sent;
    }
    final conv = _find(peerId);
    if (conv != null && conv.isPeer) return ChatLink.connected;
    return ChatLink.none;
  }

  ChatRequest? incomingFrom(String peerId) {
    for (final r in incomingChatRequests) {
      if (r.peerId == peerId) return r;
    }
    return null;
  }

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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Session binding ─────────────────────────────────────────────────────────

  /// Called whenever the signed-in user changes (see ProxyProvider in main.dart).
  void bindUser(String? userId, {bool isAgent = false}) {
    if (userId == _userId && isAgent == _isAgent) return;
    final userChanged = userId != _userId;
    _userId = userId;
    _isAgent = isAgent;
    _unsubscribeAll();
    _conversations
      ..clear()
      ..add(_makeBot())
      ..add(_makeSupport());
    _matches = [];
    _received = [];
    _sent = [];
    _chatRequests = [];
    _announcedRequests.clear();
    _announcedLikes.clear();
    _photoCache.clear();
    if (userChanged) {
      _activePeer = null;
      if (userId == null) {
        _e2ee.reset();
      } else if (Backend.ready) {
        unawaited(_e2ee.init(userId).catchError((Object e) {
          debugPrint('[ChatProvider] e2ee init failed: $e');
        }));
      }
      PresenceService.instance.bind(userId);
    }
    _notify();
    if (userId != null && Backend.ready) {
      refresh();
      _subscribe(userId);
      _subscribeSupport(userId);
      _subscribeLikes(userId);
      _subscribeRequests(userId);
    }
  }

  void _unsubscribeAll() {
    for (final ch in [_channel, _supportChannel, _likesChannel, _requestsChannel]) {
      if (ch != null) {
        try {
          Backend.client.removeChannel(ch);
        } catch (_) {}
      }
    }
    _channel = null;
    _supportChannel = null;
    _likesChannel = null;
    _requestsChannel = null;
  }

  void _onForegroundChanged() {
    if (PresenceService.instance.foreground.value) unawaited(resync());
  }

  /// Catches up after the app was in the background (Realtime does not replay
  /// what it missed): reloads the list, requests and the open conversation.
  Future<void> resync() async {
    if (_userId == null || !Backend.ready) return;
    for (final c in _conversations) {
      if (c.isPeer) c.loaded = false;
    }
    await refresh();
    final active = _activePeer;
    if (active != null) {
      await loadMessages(active, force: true);
      await markAsRead(active);
    }
  }

  Future<void> refresh() async {
    final me = _userId;
    if (me == null || !Backend.ready) return;
    loading = true;
    _notify();
    try {
      unawaited(_loadSupport());
      final matchesFuture = _travelers.matches();
      final receivedFuture = _travelers.likesReceived();
      final sentFuture = _travelers.likesSent();
      final convRows = await Backend.client.rpc('my_conversations') as List;
      _matches = await matchesFuture;
      _received = await receivedFuture;
      _sent = await sentFuture;
      await _loadChatRequests(announce: true);
      _syncConnections();
      replayPendingLikes();

      for (final raw in convRows) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['peer_id'] as String;
        final name = (r['peer_name'] as String?)?.trim();
        final display = (name == null || name.isEmpty) ? 'Traveller' : name;
        final photo = (r['peer_photo'] as String?) ?? '';
        final existing = _find(id);
        final preview = await _previewFromRow(r, me);
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
      // My phone now has everything addressed to me → tell the senders.
      unawaited(_markDelivered(null));
    } catch (e) {
      debugPrint('[ChatProvider] refresh failed: $e');
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Text shown under a conversation in the list (decrypted on this phone).
  Future<String> _previewFromRow(Map<String, dynamic> r, String me) async {
    final body = (r['last_body'] as String?) ?? '';
    final hasImage = ((r['last_image_url'] as String?) ?? '').isNotEmpty;
    final photo = hasImage ? '📷 Photo' : '';
    if (r['last_is_encrypted'] != true) return body.isNotEmpty ? body : photo;
    if (body.isEmpty) return photo;
    try {
      return SharedLocation.previewFor(await _e2ee.decryptText(
        body: body,
        senderPub: r['last_sender_pub'] as String? ?? '',
        recipientPub: r['last_recipient_pub'] as String? ?? '',
        iAmSender: r['last_sender'] == me,
      ));
    } catch (_) {
      return '🔒 Message unavailable';
    }
  }

  // ── Chat requests ───────────────────────────────────────────────────────────

  Future<void> _loadChatRequests({bool announce = false}) async {
    try {
      _chatRequests = await _repo.myRequests();
    } catch (e) {
      // Older database without chat requests: everything else keeps working.
      debugPrint('[ChatProvider] chat requests unavailable: $e');
      return;
    }
    if (announce) replayPendingRequests();
  }

  Future<void> refreshRequests() async {
    if (_userId == null || !Backend.ready) return;
    await _loadChatRequests();
    _syncConnections();
    _notify();
  }

  /// Shows the banner for requests that arrived while the app was closed. Only
  /// the newest one is announced (the rest are in Chats → Requests).
  void replayPendingRequests() {
    if (!_incomingRequestController.hasListener) return;
    final fresh = incomingChatRequests
        .where((r) => !_announcedRequests.contains(r.id))
        .toList();
    if (fresh.isEmpty) return;
    _announcedRequests.addAll(fresh.map((r) => r.id));
    _incomingRequestController.add(fresh.first);
  }

  /// Banner for likes that arrived while the app was closed (newest only).
  void replayPendingLikes() {
    if (!_incomingLikeController.hasListener) return;
    final fresh = _received.where((r) => !_announcedLikes.contains(r.id)).toList();
    if (fresh.isEmpty) return;
    _announcedLikes.addAll(fresh.map((r) => r.id));
    _incomingLikeController.add(fresh.first);
  }

  void _subscribeRequests(String me) {
    _requestsChannel = Backend.client
        .channel('rovlo-chatreq-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user',
            value: me,
          ),
          callback: (p) => _onRequestChange(p.newRecord, incoming: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'from_user',
            value: me,
          ),
          callback: (p) => _onRequestChange(p.newRecord, incoming: false),
        )
        .subscribe();
  }

  Future<void> _onRequestChange(Map<String, dynamic> row, {required bool incoming}) async {
    if (row.isEmpty) return;
    final status = row['status'] as String?;
    await _loadChatRequests();
    _syncConnections();
    _notify();

    if (incoming && status == 'pending') {
      final from = row['from_user'] as String?;
      final req = incomingChatRequests.where((r) => r.peerId == from).toList();
      if (req.isEmpty) return;
      _announcedRequests.add(req.first.id);
      if (_incomingRequestController.hasListener) {
        _incomingRequestController.add(req.first);
      }
    } else if (!incoming && status == 'accepted') {
      final to = row['to_user'] as String?;
      final who = _chatRequests.where((r) => r.peerId == to).toList();
      final name = who.isNotEmpty ? who.first.name : 'Your request';
      _notificationStreamController
          .add('$name accepted your chat request 🎉 You can chat now.');
      unawaited(refresh());
    }
  }

  /// Asks [peerId] to chat. Returns `pending`, or `accepted` when they had
  /// already asked me. Throws [ChatRequestException] with a readable message.
  Future<String> sendChatRequest(String peerId) async {
    final status = await _repo.send(peerId);
    await refreshRequests();
    return status;
  }

  Future<void> cancelChatRequest(String peerId) async {
    await _repo.cancel(peerId);
    await refreshRequests();
  }

  /// Accept / decline a request somebody sent me.
  Future<void> respondToChatRequest(ChatRequest r, {required bool accept}) async {
    await _repo.respond(r.peerId, accept: accept);
    if (accept) {
      ensureConversation(
        peerId: r.peerId,
        name: r.name,
        imageUrl: r.photoUrl,
        isVerified: r.isVerified,
      );
    }
    await refreshRequests();
  }

  // ── Like requests (Discover) ────────────────────────────────────────────────

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
      _syncConnections();
      _notify();
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
    if (req.isNotEmpty && _incomingLikeController.hasListener) {
      _announcedLikes.add(req.first.id);
      _incomingLikeController.add(req.first);
      return;
    }
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
        status: m.readAt != null ? MessageStatus.read : MessageStatus.sent,
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
      _notify();
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
    _notify();
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

  // ── Live messages ───────────────────────────────────────────────────────────

  void _subscribe(String me) {
    _channel = Backend.client
        .channel('rovlo-messages-$me')
        // New message for me.
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
        // Delivered / read receipts for messages I sent.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: me,
          ),
          callback: (payload) => _onReceipt(payload.newRecord),
        )
        .subscribe();
  }

  bool _isViewing(String peerId) =>
      _activePeer == peerId && PresenceService.instance.foreground.value;

  Future<void> _onIncoming(Map<String, dynamic> row) async {
    final from = row['sender_id'] as String;
    var conv = _find(from);
    if (conv == null) {
      // New person wrote to me — pull their card via the conversation list.
      await refresh();
      conv = _find(from);
      if (conv == null) return;
    }
    final msg = await _fromRow(row);
    if (conv.loaded) {
      if (!conv.messages.any((m) => m.id == msg.id)) conv.messages.add(msg);
    } else if (conv.loading) {
      conv.needsReload = true;
    }
    conv.lastPreview = _previewText(msg);
    conv.lastAt = msg.timestamp;

    if (_isViewing(from)) {
      // I am looking at this chat: it is read immediately.
      conv.hasUnread = false;
      unawaited(_markRead(from));
    } else {
      conv.hasUnread = true;
      unawaited(_markDelivered(from));
      _notificationStreamController.add('${conv.contactName}: ${_previewText(msg)}');
    }
    _sort();
    _notify();
  }

  String _previewText(ChatMessage m) {
    if (m.undecryptable) return '🔒 Message unavailable';
    if (m.text.isNotEmpty) return SharedLocation.previewFor(m.text);
    return m.hasImage ? '📷 Photo' : '';
  }

  void _onReceipt(Map<String, dynamic> row) {
    if (row['sender_id'] != _userId) return;
    final conv = _find(row['recipient_id'] as String? ?? '');
    final id = row['id'] as String?;
    if (conv == null || id == null) return;
    final status = row['read_at'] != null
        ? MessageStatus.read
        : (row['delivered_at'] != null ? MessageStatus.delivered : MessageStatus.sent);
    for (final m in conv.messages) {
      if (m.id == id) {
        if (status.index > m.status.index) {
          m.status = status;
          _notify();
        }
        return;
      }
    }
  }

  Future<ChatMessage> _fromRow(Map<String, dynamic> r) async {
    final isMe = r['sender_id'] == _userId;
    var text = (r['body'] as String?) ?? '';
    var undecryptable = false;
    final senderPub = r['sender_pub'] as String?;
    final recipientPub = r['recipient_pub'] as String?;
    if (r['is_encrypted'] == true && senderPub != null && recipientPub != null) {
      try {
        text = await _e2ee.decryptText(
          body: text,
          senderPub: senderPub,
          recipientPub: recipientPub,
          iAmSender: isMe,
        );
      } on E2eeException {
        text = '';
        undecryptable = true;
      }
    }
    final status = !isMe
        ? MessageStatus.read
        : (r['read_at'] != null
            ? MessageStatus.read
            : (r['delivered_at'] != null ? MessageStatus.delivered : MessageStatus.sent));
    return ChatMessage(
      id: r['id'] as String?,
      text: text,
      imageUrl: r['image_url'] as String?,
      isMe: isMe,
      timestamp: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal(),
      status: status,
      senderPub: senderPub,
      recipientPub: recipientPub,
      undecryptable: undecryptable,
    );
  }

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
    );
    _conversations.add(conv);
    _sort();
    _notify();
    return conv;
  }

  /// The chat screen calls this while it is open so new messages are marked as
  /// read straight away (and no banner is shown for them).
  void setActivePeer(String? peerId) {
    _activePeer = peerId;
  }

  // ── History / read state ────────────────────────────────────────────────────

  Future<void> loadMessages(String peerId, {bool force = false}) async {
    final conv = _find(peerId);
    final me = _userId;
    if (conv == null || conv.isBot || me == null) return;
    if (conv.loaded && !force) return;
    if (conv.isSupport) {
      await _loadSupport();
      return;
    }
    if (conv.loading) {
      conv.needsReload = true;
      return;
    }
    conv.loading = true;
    try {
      do {
        conv.needsReload = false;
        final rows = await Backend.client
            .from('messages')
            .select()
            .or('and(sender_id.eq.$me,recipient_id.eq.$peerId),and(sender_id.eq.$peerId,recipient_id.eq.$me)')
            .order('created_at', ascending: false)
            .limit(200);
        final loaded = <ChatMessage>[];
        for (final row in rows.reversed) {
          loaded.add(await _fromRow(row));
        }
        // Keep messages that are still on their way out.
        final inFlight =
            conv.messages.where((m) => m.status == MessageStatus.sending).toList();
        conv.messages
          ..clear()
          ..addAll(loaded)
          ..addAll(inFlight);
        conv.loaded = true;
        _notify();
      } while (conv.needsReload);
    } catch (e) {
      debugPrint('[ChatProvider] loadMessages failed: $e');
    } finally {
      conv.loading = false;
    }
  }

  Future<void> markAsRead(String peerId) async {
    final conv = _find(peerId);
    if (conv == null) return;
    final hadUnread = conv.hasUnread;
    if (hadUnread) {
      conv.hasUnread = false;
      _notify();
    }
    if (conv.isBot || !Backend.ready) return;
    if (conv.isSupport) {
      if (hadUnread) await SupportService.instance.markMineRead();
      return;
    }
    await _markRead(peerId);
  }

  Future<void> _markRead(String peerId) async {
    try {
      await Backend.client.rpc('mark_conversation_read', params: {'p_peer': peerId});
    } catch (e) {
      debugPrint('[ChatProvider] mark read failed: $e');
    }
  }

  Future<void> _markDelivered(String? peerId) async {
    if (!Backend.ready || _userId == null) return;
    try {
      await Backend.client.rpc('mark_delivered', params: {'p_peer': peerId});
    } catch (e) {
      debugPrint('[ChatProvider] mark delivered failed: $e');
    }
  }

  // ── Sending ─────────────────────────────────────────────────────────────────

  /// Sends text. For people the message is encrypted on this phone first.
  /// Throws if it could not be stored (the bubble is then removed).
  ///
  /// [imageUrl] is only for the (non-encrypted) support thread; photos to people
  /// go through [sendPhoto].
  Future<void> sendMessage(
    String peerId,
    String text,
    AppUser? currentUser, {
    String? imageUrl,
  }) async {
    final conv = _find(peerId);
    if (conv == null) return;

    final isPeer = conv.isPeer;
    final msg = ChatMessage(
      text: text,
      imageUrl: imageUrl,
      isMe: true,
      status: isPeer ? MessageStatus.sending : MessageStatus.sent,
    );
    conv.messages.add(msg);
    conv.lastAt = msg.timestamp;
    _sort();
    _notify();

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
      final row = await _insertEncrypted(peerId, text: text);
      _applySent(conv, msg, row);
      _pushIfOffline(peerId);
    } catch (e) {
      conv.messages.remove(msg);
      _notify();
      rethrow;
    }
  }

  /// Sends a photo to a person: the image is encrypted on this phone and only
  /// the ciphertext is uploaded to the private `chat-secure` bucket.
  Future<void> sendPhoto(String peerId, Uint8List bytes, {String caption = ''}) async {
    final conv = _find(peerId);
    if (conv == null || !conv.isPeer) return;

    final msg = ChatMessage(
      text: caption,
      imageUrl: 'e2ee:pending',
      isMe: true,
      status: MessageStatus.sending,
    );
    // Show my own photo immediately from memory.
    _pendingPhotos[msg] = bytes;
    conv.messages.add(msg);
    conv.lastAt = msg.timestamp;
    _sort();
    _notify();

    try {
      final row = await _insertEncrypted(peerId, text: caption, photo: bytes);
      final ref = row['image_url'] as String?;
      if (ref != null) _photoCache[ref] = Future.value(bytes);
      _applySent(conv, msg, row, replaceImage: ref);
      _pendingPhotos.remove(msg);
      _pushIfOffline(peerId);
    } catch (e) {
      _pendingPhotos.remove(msg);
      conv.messages.remove(msg);
      _notify();
      rethrow;
    }
  }

  void _applySent(
    ChatConversation conv,
    ChatMessage msg,
    Map<String, dynamic> row, {
    String? replaceImage,
  }) {
    final index = conv.messages.indexOf(msg);
    final at = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    if (replaceImage != null && index >= 0) {
      // The bubble now points at the real (encrypted) file.
      final updated = ChatMessage(
        id: row['id'] as String?,
        text: msg.text,
        imageUrl: replaceImage,
        isMe: true,
        timestamp: at ?? msg.timestamp,
        status: MessageStatus.sent,
        senderPub: row['sender_pub'] as String?,
        recipientPub: row['recipient_pub'] as String?,
      );
      conv.messages[index] = updated;
    } else {
      msg.id = row['id'] as String?;
      if (at != null) msg.timestamp = at;
      msg.status = MessageStatus.sent;
    }
    conv.lastAt = at ?? conv.lastAt;
    conv.lastPreview =
        msg.text.isNotEmpty ? SharedLocation.previewFor(msg.text) : '📷 Photo';
    _sort();
    _notify();
  }

  /// Sends my current position to [peerId] (encrypted like any message).
  Future<void> sendLocation(String peerId, double lat, double lng) =>
      sendMessage(peerId, SharedLocation.encode(lat, lng), null);

  /// Encrypts, (uploads the photo) and inserts. Retries once with a fresh copy
  /// of the other person's key when the database says the key we used is stale.
  Future<Map<String, dynamic>> _insertEncrypted(
    String peerId, {
    String text = '',
    Uint8List? photo,
  }) async {
    final me = _userId;
    if (me == null) throw StateError('Not signed in');
    // '📷 Photo' is only a UI placeholder, never a real message.
    final clean = text == '📷 Photo' && photo != null ? '' : text;

    for (var attempt = 0;; attempt++) {
      final session = await _e2ee.sessionFor(peerId, refreshPeer: attempt > 0);
      String? imageRef;
      if (photo != null) {
        final blob = await session.encryptBytes(photo);
        final path = '$me/${E2eeService.randomName()}.bin';
        await Backend.client.storage.from('chat-secure').uploadBinary(
              path,
              blob,
              fileOptions: const FileOptions(
                contentType: 'application/octet-stream',
                cacheControl: '31536000',
              ),
            );
        imageRef = 'e2ee:$path';
      }
      try {
        final row = await Backend.client
            .from('messages')
            .insert({
              'sender_id': me,
              'recipient_id': peerId,
              'body': await session.encryptText(clean),
              if (imageRef != null) 'image_url': imageRef,
              ...session.columns,
            })
            .select()
            .single();
        return Map<String, dynamic>.from(row);
      } on PostgrestException catch (e) {
        final stale = e.code == '42501';
        if (attempt == 0 && stale) continue;
        rethrow;
      }
    }
  }

  /// Push only when the other person is not in the app (presence says so).
  /// The push never contains the message text.
  void _pushIfOffline(String peerId) {
    if (PresenceService.instance.isOnline(peerId)) return;
    unawaited(ChatRepository.pushNotify('message', peerId));
  }

  // ── Encrypted photos ────────────────────────────────────────────────────────

  /// Decrypted bytes of an encrypted photo (downloaded once, then cached).
  Future<Uint8List> photoBytes(ChatMessage m) {
    final ref = m.imageUrl!;
    final cached = _photoCache[ref];
    if (cached != null) return cached;
    final future = _downloadPhoto(m);
    _photoCache[ref] = future;
    // Don't cache failures — let the user retry.
    unawaited(future.then((_) {}, onError: (Object _) => _photoCache.remove(ref)));
    return future;
  }

  Future<Uint8List> _downloadPhoto(ChatMessage m) async {
    final senderPub = m.senderPub;
    final recipientPub = m.recipientPub;
    if (senderPub == null || recipientPub == null) {
      throw E2eeException('Missing keys for this photo.');
    }
    final blob = await Backend.client.storage
        .from('chat-secure')
        .download(E2eeService.imagePath(m.imageUrl!));
    return _e2ee.decryptBytes(
      blob: blob,
      senderPub: senderPub,
      recipientPub: recipientPub,
      iAmSender: m.isMe,
    );
  }

  /// Bytes of my own photo that is still uploading (null once it is sent).
  Uint8List? pendingPhoto(ChatMessage m) => _pendingPhotos[m];

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
    _notify();
    _notificationStreamController.add('Rovlo: $reply');
  }

  @override
  void dispose() {
    _disposed = true;
    PresenceService.instance.foreground.removeListener(_onForegroundChanged);
    _unsubscribeAll();
    _supportEvents.close();
    _incomingRequestController.close();
    _incomingLikeController.close();
    _notificationStreamController.close();
    super.dispose();
  }
}
