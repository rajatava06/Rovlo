import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'chat_room_screen.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecColor = context.rovlo.textSecondary;
    final cardColor = context.rovlo.card;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    // Mock data matching the screenshot
    final List<_NewMatch> newMatches = [
      _NewMatch(
        name: 'Elena',
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
      ),
      _NewMatch(
        name: 'Marcus',
        imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80',
        isVerified: false,
      ),
      _NewMatch(
        name: 'Sora',
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
      ),
      _NewMatch(
        name: 'Julian',
        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
      ),
    ];

    final List<_MessagePreview> messages = [
      _MessagePreview(
        name: 'Elena Rossi',
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
        snippet: 'Looking forward to Tokyo...',
        time: '2m ago',
        isVerified: true,
        unread: true,
        active: true,
      ),
      _MessagePreview(
        name: 'Marcus Chen',
        imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80',
        snippet: 'That café in Omotesando loo...',
        time: '15m ago',
        isVerified: false,
        unread: false,
        active: false,
      ),
      _MessagePreview(
        name: 'Sora Tanaka',
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
        snippet: 'Did you check the itinerary I ...',
        time: '1h ago',
        isVerified: true,
        unread: false,
        active: false,
      ),
      _MessagePreview(
        name: 'Julian Weber',
        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
        snippet: 'Haha, that\'s so true about th...',
        time: '3h ago',
        isVerified: true,
        unread: false,
        active: false,
      ),
      _MessagePreview(
        name: 'Maya Patel',
        imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=150&q=80',
        snippet: 'Can\'t wait for our trip! See yo...',
        time: 'Yesterday',
        isVerified: false,
        unread: false,
        active: false,
      ),
    ];

    void openChatRoom(String name, String imageUrl, bool isVerified) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            args: ChatRoomArgs(
              name: name,
              imageUrl: imageUrl,
              isVerified: isVerified,
            ),
          ),
        ),
      );
    }

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
                  Icon(
                    Icons.chat_bubble_outline,
                    color: primaryPeach,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // ── New Matches Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'NEW MATCHES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // ── New Matches Scroll ──────────────────────────────────────────────
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: newMatches.length,
                itemBuilder: (context, index) {
                  final match = newMatches[index];
                  return GestureDetector(
                    onTap: () => openChatRoom(match.name, match.imageUrl, match.isVerified),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryPeach.withValues(alpha: 0.5), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundImage: NetworkImage(match.imageUrl),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            match.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Messages Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'MESSAGES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // ── Messages List ──────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return GestureDetector(
                    onTap: () => openChatRoom(msg.name, msg.imageUrl, msg.isVerified),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: NetworkImage(msg.imageUrl),
                              ),
                              if (msg.active)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cardColor,
                                        width: 2.5,
                                      ),
                                    ),
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
                                    Text(
                                      msg.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (msg.isVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: AppColors.primary, size: 14),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.snippet,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: msg.unread
                                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                                        : textSecColor,
                                    fontWeight: msg.unread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecColor.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (msg.unread)
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMatch {
  final String name;
  final String imageUrl;
  final bool isVerified;

  const _NewMatch({
    required this.name,
    required this.imageUrl,
    required this.isVerified,
  });
}

class _MessagePreview {
  final String name;
  final String imageUrl;
  final String snippet;
  final String time;
  final bool isVerified;
  final bool unread;
  final bool active;

  const _MessagePreview({
    required this.name,
    required this.imageUrl,
    required this.snippet,
    required this.time,
    required this.isVerified,
    required this.unread,
    required this.active,
  });
}
