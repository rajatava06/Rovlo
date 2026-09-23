import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/widgets/keyboard_inset.dart';
import '../../services/media_service.dart';
import 'traveler_profile_screen.dart';

class ChatRoomArgs {
  final String peerId;
  final String name;
  final String imageUrl;
  final bool isVerified;

  const ChatRoomArgs({
    required this.peerId,
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
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  bool get _isBot => widget.args.peerId == kBotId;
  bool get _isSupport => widget.args.peerId == kSupportId;
  bool get _isSystem => _isBot || _isSupport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = Provider.of<ChatProvider>(context, listen: false);
      await chat.loadMessages(widget.args.peerId);
      chat.markAsRead(widget.args.peerId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? customText, String? imageUrl}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty && imageUrl == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    if (customText == null && imageUrl == null) {
      _textController.clear();
    }
    _scrollToBottom();

    try {
      await chatProvider.sendMessage(
        widget.args.peerId,
        text.isNotEmpty ? text : '📷 Photo',
        authProvider.currentUser,
        imageUrl: imageUrl,
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Message not sent. Check your connection and try again.'),
      ));
    }
  }

  Future<void> _handlePickAndSendImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      // Upload to Supabase Storage (bucket: chat-media)
      final uploadedUrl =
          await MediaService.instance.uploadXFile(picked, bucket: 'chat-media');

      if (mounted) {
        setState(() => _isUploadingImage = false);
        _sendMessage(customText: '', imageUrl: uploadedUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    }
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
              subtitle: const Text('Uploaded securely to Rovlo cloud'),
              onTap: () {
                Navigator.pop(ctx);
                _handlePickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Capture with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _handlePickAndSendImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: _buildImageWidget(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 180,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 140,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else if (!kIsWeb && (url.startsWith('/') || url.contains(':\\') || url.startsWith('file:'))) {
      final cleanPath = url.replaceFirst('file://', '');
      return Image.file(
        File(cleanPath),
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          height: 140,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    } else {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          height: 140,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final textSecColor = context.rovlo.textSecondary;

    final chatProvider = context.watch<ChatProvider>();
    final conv = chatProvider.getConversation(widget.args.peerId);
    final messages = conv?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            if (_isSystem) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isSupport
                      ? 'Rovlo Support: send us a message or a photo and the team will reply here.'
                      : '🤖 Rovlo is your automated travel assistant!'),
                ),
              );
              return;
            }

            final traveler = Traveler(
              id: widget.args.peerId,
              name: widget.args.name,
              age: 0,
              imageUrl: widget.args.imageUrl,
              imageUrls: [widget.args.imageUrl],
              location: '',
              dateRange: '',
              tags: const [],
              isVerified: widget.args.isVerified,
              description: '',
              about: '',
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TravelerProfileScreen(traveler: traveler),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  _isSystem
                      ? Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/rovlo_icon.png',
                            color: Colors.white,
                            fit: BoxFit.contain,
                          ),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundImage: CachedNetworkImageProvider(widget.args.imageUrl),
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.args.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.primary, size: 16),
                        ],
                      ],
                    ),
                    Text(
                      _isSupport ? 'Support team' : (_isBot ? 'Travel Assistant Bot' : 'Online'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _isSystem ? AppColors.primary : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: KeyboardAvoiding(
        child: Column(
        children: [
          if (_showSafetyBanner && !_isSystem)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEEE8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCCB8)),
              ),
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
            child: (_isSupport && messages.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'Hi! 👋 How can we help?\nSend a message or a photo and the Rovlo team will reply here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecColor, height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
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
                        _isSystem
                            ? Container(
                                width: 28,
                                height: 28,
                                padding: const EdgeInsets.all(5.5),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/rovlo_icon.png',
                                  color: Colors.white,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : CircleAvatar(
                                radius: 14,
                                backgroundImage: CachedNetworkImageProvider(widget.args.imageUrl),
                              ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: msg.hasImage
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: msg.isMe
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkCard : const Color(0xFFEBEBEB)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(msg.isMe ? 16 : 0),
                                  bottomRight: Radius.circular(msg.isMe ? 0 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (msg.hasImage) ...[
                                    GestureDetector(
                                      onTap: () => _showImagePreview(msg.imageUrl!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 220,
                                            maxWidth: 240,
                                          ),
                                          child: _buildImageWidget(msg.imageUrl!),
                                        ),
                                      ),
                                    ),
                                    if (msg.text.isNotEmpty && msg.text != '📷 Photo') ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Text(
                                          msg.text,
                                          style: TextStyle(
                                            color: msg.isMe
                                                ? Colors.white
                                                : (isDark ? Colors.white : AppColors.lightTextPrimary),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ] else
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        color: msg.isMe
                                            ? Colors.white
                                            : (isDark ? Colors.white : AppColors.lightTextPrimary),
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                ],
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

          if (_isUploadingImage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primaryPeach.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Uploading photo...',
                    style: TextStyle(fontSize: 12, color: primaryPeach, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          SafeArea(
            top: false,
            bottom: context.keyboardInset == 0,
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
                                isCollapsed: true,
                                hintText: 'Type a message...',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
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
      ),
    );
  }
}
