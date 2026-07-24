import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  bool get _isBot => widget.args.name == 'Rovlo';

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

  void _sendMessage({String? customText}) {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    chatProvider.sendMessage(widget.args.name, text, authProvider.currentUser);
    if (customText == null) {
      _textController.clear();
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  void _showEmojiPicker() {
    final emojis = ['😊', '✈️', '🌍', '❤️', '🌊', '🏔️', '🍕', '🎒', '🎉', '👍', '🔥', '🏖️', '📸', '✨', '👋', '🍹'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _textController.text += emojis[index];
                    });
                    Navigator.pop(context);
                  },
                  child: Center(
                    child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Send Photo from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  _sendMessage(customText: '📷 Sent a photo');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Capture with Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  _sendMessage(customText: '📷 Captured photo');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text('Share Live Location'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage(customText: '📍 Shared current location');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _makeAudioCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Calling ${widget.args.name}...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(widget.args.imageUrl),
            ),
            const SizedBox(height: 16),
            const Text('Audio call in progress...', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('End Call', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            if (_isBot) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🤖 Rovlo is your automated travel assistant!')),
              );
              return;
            }

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
              _isBot
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundImage: AssetImage('assets/images/rovlo_logo.jpg'),
                      ),
                    )
                  : CircleAvatar(
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
                  Text(
                    _isBot ? 'Automated Bot 🤖' : 'Active now',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isBot ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Audio Call ONLY
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: _makeAudioCall,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSafetyBanner && !_isBot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFFEEADF),
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

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg.isMe) ...[
                        _isBot
                            ? Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF6B35),
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundImage: AssetImage('assets/images/rovlo_logo.jpg'),
                                ),
                              )
                            : CircleAvatar(
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
                                    ? const Color(0xFF8B5A2B)
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
              },
            ),
          ),

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
                            onPressed: _showEmojiPicker,
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
                            onPressed: _showAttachmentPicker,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(),
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
