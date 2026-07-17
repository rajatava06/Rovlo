import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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
  final List<_Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSafetyBanner = true;

  @override
  void initState() {
    super.initState();
    // Default initial mock messages
    _messages.addAll([
      _Message(
        text: 'Hey! I saw you\'re also going to be in Shinjuku for Halloween. Want to grab ramen?',
        isMe: false,
        time: '2:14 PM',
      ),
      _Message(
        text: 'That sounds amazing! I\'ve been dying to try Ichiran or maybe something more local. Do you have a favorite spot?',
        isMe: true,
        time: '2:15 PM',
      ),
      _Message(
        text: 'I actually know a hidden gem in Golden Gai that\'s much better than the chains. I\'ll send you the location! 🍜',
        isMe: false,
        time: '2:16 PM',
      ),
    ]);
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

    setState(() {
      _messages.add(_Message(
        text: text,
        isMe: true,
        time: '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} ${TimeOfDay.now().period == DayPeriod.am ? 'AM' : 'PM'}',
      ));
      _textController.clear();
    });

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Simulated reply after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(
          text: 'Awesome, looking forward to meeting up! Let\'s finalize coordinates closer to the date.',
          isMe: false,
          time: '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} ${TimeOfDay.now().period == DayPeriod.am ? 'AM' : 'PM'}',
        ));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final textSecColor = context.rovlo.textSecondary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.args.imageUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.args.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.args.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 14),
                      ],
                    ],
                  ),
                  const Text(
                    'Active now',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
          ),
        ],
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
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
                          const SizedBox(width: -8),
                          Container(
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
                        ],
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
                ..._messages.map((msg) {
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
                                    msg.time,
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

          // ── Bottom Message Composer Bar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: AppColors.accent),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.image_outlined, color: AppColors.accent),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5A2B), // Brown background matching message bubbles
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
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

class _Message {
  final String text;
  final bool isMe;
  final String time;

  const _Message({
    required this.text,
    required this.isMe,
    required this.time,
  });
}
