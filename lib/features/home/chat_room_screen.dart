import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'traveler_profile_screen.dart';

class ChatRoomArgs {
  final String name;
  final String imageUrl;
  final bool isVerified;

  const ChatRoomArgs({
    required this.name,
    required this.imageUrl,
    required this.isVerified,
  });
}

class ChatRoomScreen extends StatefulWidget {
  final ChatRoomArgs args;

  const ChatRoomScreen({super.key, required this.args});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSafetyBanner = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).markAsRead(widget.args.name);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    chatProvider.sendMessage(widget.args.name, text, authProvider.currentUser);
    _textController.clear();

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final textSecColor = context.rovlo.textSecondary;

    final chatProvider = context.watch<ChatProvider>();
    final conv = chatProvider.getConversation(widget.args.name);
    final messages = conv?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            final travelerName = widget.args.name;
            final matchingTravelers = SampleTravelers.list.where((t) => t.name == travelerName);
            final traveler = matchingTravelers.isNotEmpty
                ? matchingTravelers.first
                : Traveler(
                    name: widget.args.name,
                    age: 24,
                    imageUrl: widget.args.imageUrl,
                    imageUrls: [widget.args.imageUrl],
                    location: 'Tokyo',
                    dateRange: 'Oct 25 - Nov 2',
                    tags: ['Backpacker'],
                    isVerified: widget.args.isVerified,
                    description: 'Hey! Let\'s chat and travel together!',
                    about: 'Hey! I\'m ${widget.args.name}. Let\'s explore the city and hang out!',
                  );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelerProfileScreen(traveler: traveler),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.args.imageUrl),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.args.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (widget.args.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                      ],
                    ],
                  ),
                  const Text(
                    'Active now',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Safety Banner ────────────────────────────────────────────────────
          if (_showSafetyBanner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFFEEADF), // Pale peach banner
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Meeting for the first time? Check our safety guidelines.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E4A35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Color(0xFF7E4A35), size: 18),
                    onPressed: () {
                      setState(() {
                        _showSafetyBanner = false;
                      });
                    },
                  ),
                ],
              ),
            ),

          // ── Scrollable Chat Room Feed ────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // Matched Info / Intwined avatars
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 46,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  color: primaryPeach,
                                ),
                                child: const Center(
                                  child: Text(
                                    'Me',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 38,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  image: DecorationImage(
                                    image: NetworkImage(widget.args.imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF0E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.map_outlined, color: AppColors.primary, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              'You both have an overlap in ${widget.args.name.split(' ').first}\'s location next month! Say hi.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF6B4533),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'MATCHED TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: textSecColor.withValues(alpha: 0.6),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Bubbles List
                ...messages.map((msg) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!msg.isMe) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(widget.args.imageUrl),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: msg.isMe
                                      ? const Color(0xFF8B5A2B) // Warm brown message bubble
                                      : (isDark ? AppColors.darkCard : const Color(0xFFEBEBEB)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(msg.isMe ? 16 : 0),
                                    bottomRight: Radius.circular(msg.isMe ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: msg.isMe
                                        ? Colors.white
                                        : (isDark ? Colors.white : AppColors.lightTextPrimary),
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg.timeFormatted,
                                    style: TextStyle(
                                      color: textSecColor.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (msg.isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.done_all, color: Colors.blue, size: 12),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Bottom Message Input Field ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.sentiment_satisfied_alt_outlined, color: textSecColor),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                filled: false,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.attach_file, color: textSecColor),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryPeach,
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
