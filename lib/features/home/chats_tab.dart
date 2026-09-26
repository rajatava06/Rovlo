import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/online_dot.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_repository.dart';
import '../../services/traveler_repository.dart';
import 'chat_request_actions.dart';
import 'chat_room_screen.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecColor = context.rovlo.textSecondary;
    final cardColor = context.rovlo.card;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;

    final newMatches = chatProvider.newMatches;
    final requests = chatProvider.requests;
    final pending = chatProvider.pending;
    final chatRequestsIn = chatProvider.incomingChatRequests;
    final chatRequestsOut = chatProvider.outgoingChatRequests;
    final hasTopRow = requests.isNotEmpty ||
        newMatches.isNotEmpty ||
        pending.isNotEmpty ||
        chatRequestsOut.isNotEmpty;

    void openChatRoom(String peerId, String name, String imageUrl, bool isVerified) {
      openChatWith(
        context,
        peerId: peerId,
        name: name,
        imageUrl: imageUrl,
        isVerified: isVerified,
      );
    }

    // One entry per bubble: people who liked me first, then new chats, then
    // people I asked / liked who have not answered yet.
    final bubbles = <_Bubble>[
      for (final r in requests)
        _Bubble(
          id: r.id,
          name: r.name,
          photoUrl: r.photoUrl,
          kind: _BubbleKind.likesYou,
          onTap: () => _showRequestSheet(context, r),
        ),
      for (final m in newMatches)
        _Bubble(
          id: m.id,
          name: m.name,
          photoUrl: m.photoUrl,
          kind: _BubbleKind.match,
          onTap: () => openChatRoom(m.id, m.name, m.photoUrl, m.isVerified),
        ),
      for (final r in chatRequestsOut)
        _Bubble(
          id: r.peerId,
          name: r.name,
          photoUrl: r.photoUrl,
          kind: _BubbleKind.pending,
          onTap: () => _showSentRequestSheet(context, r),
        ),
      for (final p in pending)
        _Bubble(
          id: p.id,
          name: p.name,
          photoUrl: p.photoUrl,
          kind: _BubbleKind.pending,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Waiting for ${p.name} to accept your like. '
                  'You can chat as soon as they do. 💙'),
            ),
          ),
        ),
    ];

    Widget sectionTitle(String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecColor,
                  letterSpacing: 0.8,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar Area ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: primaryPeach, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                  ),
                ],
              ),
            ),

            // Everything below scrolls together (requests, new chats, messages).
            Expanded(
              child: RefreshIndicator(
                onRefresh: chatProvider.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 110),
                  children: [
                    // ── Chat requests (accept / decline right here) ─────────────
                    if (chatRequestsIn.isNotEmpty) ...[
                      sectionTitle(
                        'CHAT REQUESTS',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryPeach,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chatRequestsIn.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      _RequestsList(requests: chatRequestsIn, accent: primaryPeach),
                      const SizedBox(height: 8),
                    ],

                    // ── New chats / pending ─────────────────────────────────────
                    if (hasTopRow) ...[
                      sectionTitle('NEW MATCHES'),
                      SizedBox(
                        height: 112,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          scrollDirection: Axis.horizontal,
                          itemCount: bubbles.length,
                          itemBuilder: (context, index) => _BubbleView(
                            bubble: bubbles[index],
                            accent: primaryPeach,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Messages ────────────────────────────────────────────────
                    sectionTitle('MESSAGES'),
                    for (final conv in conversations)
                      _ConversationTile(
                        conv: conv,
                        isDark: isDark,
                        cardColor: cardColor,
                        textSecColor: textSecColor,
                        primaryPeach: primaryPeach,
                        onTap: () => openChatRoom(
                          conv.peerId,
                          conv.contactName,
                          conv.contactImageUrl,
                          conv.isVerified,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat requests ────────────────────────────────────────────────────────────

/// Requests waiting for my answer, each with Accept / Decline buttons. Shows the
/// newest three and lets me expand the rest.
class _RequestsList extends StatefulWidget {
  const _RequestsList({required this.requests, required this.accent});

  final List<ChatRequest> requests;
  final Color accent;

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  static const int _collapsed = 3;
  bool _expanded = false;
  final Set<String> _busy = {};

  Future<void> _answer(ChatRequest r, bool accept) async {
    setState(() => _busy.add(r.id));
    await answerChatRequest(context, r, accept: accept, openChat: accept);
    if (mounted) setState(() => _busy.remove(r.id));
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.requests;
    final shown = _expanded ? list : list.take(_collapsed).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = context.rovlo.textSecondary;

    return Column(
      children: [
        for (final r in shown)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.rovlo.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: 0.35), width: 1.4),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: CachedNetworkImageProvider(r.photoUrl),
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: OnlineDot(
                            userId: r.peerId,
                            size: 13,
                            borderColor: context.rovlo.card,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.nameWithAge,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (r.isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, color: widget.accent, size: 14),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.city.isNotEmpty
                                ? 'wants to chat with you · ${r.city}'
                                : 'wants to chat with you',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSec),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy.contains(r.id) ? null : () => _answer(r, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _busy.contains(r.id) ? null : () => _answer(r, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accent,
                          minimumSize: const Size.fromHeight(42),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _busy.contains(r.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (list.length > _collapsed)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show ${list.length - _collapsed} more'),
          ),
      ],
    );
  }
}

/// Tapping a request I sent: it is still waiting — offer to cancel it.
Future<void> _showSentRequestSheet(BuildContext context, ChatRequest r) async {
  final chat = context.read<ChatProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final cancel = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 40, backgroundImage: CachedNetworkImageProvider(r.photoUrl)),
          const SizedBox(height: 12),
          Text(r.nameWithAge,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Your chat request is waiting for ${r.name} to accept.\n'
            "You'll get a notification as soon as they do.",
            textAlign: TextAlign.center,
            style: TextStyle(color: ctx.rovlo.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    ),
  );
  if (cancel != true) return;
  try {
    await chat.cancelChatRequest(r.peerId);
    messenger.showSnackBar(SnackBar(content: Text('Request to ${r.name} cancelled.')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not cancel. Check your connection.')),
    );
  }
}

// ── Conversation row ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conv,
    required this.isDark,
    required this.cardColor,
    required this.textSecColor,
    required this.primaryPeach,
    required this.onTap,
  });

  final ChatConversation conv;
  final bool isDark;
  final Color cardColor;
  final Color textSecColor;
  final Color primaryPeach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (conv.isBot || conv.isSupport)
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: primaryPeach, shape: BoxShape.circle),
                    child: Image.asset(
                      'assets/images/rovlo_icon.png',
                      color: Colors.white,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: CachedNetworkImageProvider(conv.contactImageUrl),
                  ),
                if (conv.isPeer)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: OnlineDot(
                      userId: conv.peerId,
                      size: 15,
                      borderColor: cardColor,
                      borderWidth: 2.5,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conv.contactName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (conv.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conv.previewText,
                    style: TextStyle(
                      fontSize: 13,
                      color: conv.hasUnread
                          ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                          : textSecColor,
                      fontWeight: conv.hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conv.timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                if (conv.hasUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5A2B), // Brown dot representing unread message
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Like requests ────────────────────────────────────────────────────────────

enum _BubbleKind { likesYou, match, pending }

class _Bubble {
  const _Bubble({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.kind,
    required this.onTap,
  });

  final String id;
  final String name;
  final String photoUrl;
  final _BubbleKind kind;
  final VoidCallback onTap;
}

class _BubbleView extends StatelessWidget {
  const _BubbleView({required this.bubble, required this.accent});

  final _Bubble bubble;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isPending = bubble.kind == _BubbleKind.pending;
    final isRequest = bubble.kind == _BubbleKind.likesYou;
    final ring = isRequest ? const Color(0xFFFF5C8A) : accent;
    final caption = switch (bubble.kind) {
      _BubbleKind.likesYou => 'Likes you',
      _BubbleKind.pending => 'Pending',
      _BubbleKind.match => 'New match',
    };
    final captionColor = switch (bubble.kind) {
      _BubbleKind.likesYou => const Color(0xFFFF5C8A),
      _BubbleKind.pending => context.rovlo.textSecondary,
      _BubbleKind.match => accent,
    };

    return GestureDetector(
      onTap: bubble.onTap,
      child: Container(
        width: 78,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ring.withValues(alpha: isPending ? 0.25 : 0.9),
                      width: 2,
                    ),
                  ),
                  child: Opacity(
                    opacity: isPending ? 0.55 : 1,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: CachedNetworkImageProvider(bubble.photoUrl),
                    ),
                  ),
                ),
                if (isRequest || isPending)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isRequest ? const Color(0xFFFF5C8A) : Colors.grey.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isRequest ? Icons.favorite : Icons.schedule,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              bubble.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              caption,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: captionColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for somebody who liked me: accept (→ match, chat opens) or
/// decline (they disappear).
Future<void> _showRequestSheet(BuildContext context, LikeRequest r) async {
  final chat = context.read<ChatProvider>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: CachedNetworkImageProvider(r.photoUrl),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    r.nameWithAge,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                if (r.isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, color: primary, size: 20),
                ],
              ],
            ),
            if (r.city.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(r.city, style: TextStyle(color: ctx.rovlo.textSecondary)),
            ],
            const SizedBox(height: 12),
            Text(
              '${r.name} liked you 💙\nAccept to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ctx.rovlo.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'decline'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  if (action == null) return;
  try {
    if (action == 'accept') {
      final match = await chat.acceptRequest(r.id);
      chat.ensureConversation(
        peerId: r.id,
        name: r.name,
        imageUrl: r.photoUrl,
        isVerified: r.isVerified,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(match
            ? "It's a match with ${r.name}! 🎉 You can chat now."
            : 'Accepted.'),
      ));
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            args: ChatRoomArgs(
              peerId: r.id,
              name: r.name,
              imageUrl: r.photoUrl,
              isVerified: r.isVerified,
            ),
          ),
        ),
      );
    } else {
      await chat.declineRequest(r.id);
      messenger.showSnackBar(SnackBar(content: Text('Declined ${r.name}.')));
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not do that. Check your connection.')),
    );
  }
}
