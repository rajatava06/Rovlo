import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/backend.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/keyboard_inset.dart';
import '../../core/widgets/online_dot.dart';
import '../../models/traveler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/app_navigation.dart';
import '../../services/e2ee_service.dart';
import '../../services/location_service.dart';
import '../../services/media_service.dart';
import '../../services/typing_channel.dart';
import '../../services/voice_input_service.dart';
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
  static const Color _readBlue = Color(0xFF34B7F1);
  static const int _maxChars = 2000;

  /// Second line of the attach-menu items: small and light grey.
  static const TextStyle _pickerHintStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9AA3AF),
    height: 1.3,
  );

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceInputService _voice = VoiceInputService();
  final ValueNotifier<bool> _noTyping = ValueNotifier<bool>(false);

  late final ChatProvider _chat;
  TypingChannel? _typing;
  Timer? _typingIdle;

  bool _showSafetyBanner = true;
  bool _isUploadingImage = false;
  bool _voiceActive = false;
  VoiceLang _voiceLang = VoiceLang.english;
  int _lastCount = 0;

  bool get _isBot => widget.args.peerId == kBotId;
  bool get _isSupport => widget.args.peerId == kSupportId;
  bool get _isSystem => _isBot || _isSupport;
  ValueNotifier<bool> get _peerTyping => _typing?.peerTyping ?? _noTyping;

  @override
  void initState() {
    super.initState();
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _chat.setActivePeer(widget.args.peerId);

    final me = Backend.uid;
    if (!_isSystem && me != null) {
      _typing = TypingChannel(me: me, peer: widget.args.peerId);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chat.loadMessages(widget.args.peerId);
      await _chat.markAsRead(widget.args.peerId);
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    _chat.setActivePeer(null);
    _typingIdle?.cancel();
    unawaited(_typing?.dispose());
    unawaited(_voice.dispose());
    _noTyping.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Typing ──────────────────────────────────────────────────────────────────

  void _onTextChanged(String value) {
    final typing = _typing;
    if (typing == null) return;
    if (value.trim().isEmpty) {
      _typingIdle?.cancel();
      typing.stopped();
      return;
    }
    typing.typing();
    _typingIdle?.cancel();
    _typingIdle = Timer(const Duration(seconds: 3), typing.stopped);
  }

  // ── Sending ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    _textController.clear();
    _typingIdle?.cancel();
    _typing?.stopped();
    _scrollToBottom();

    try {
      await _chat.sendMessage(widget.args.peerId, text, authProvider.currentUser);
    } catch (e) {
      // Give the text back so nothing typed is lost.
      if (mounted && _textController.text.isEmpty) {
        _textController.text = text;
        _textController.selection = TextSelection.collapsed(offset: text.length);
      }
      messenger.showSnackBar(SnackBar(content: Text(_sendError(e))));
    }
  }

  String _sendError(Object e) {
    if (e is E2eeException) return e.message;
    if (e is PostgrestException && e.code == '42501') {
      return 'You can only message people who accepted your chat request.';
    }
    return 'Message not sent. Check your connection and try again.';
  }

  Future<void> _handlePickAndSendImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      if (_isSystem) {
        // Bot / support photos are not encrypted (staff must be able to see them).
        setState(() => _isUploadingImage = true);
        final url = await MediaService.instance.uploadXFile(picked, bucket: 'chat-media');
        if (!mounted) return;
        setState(() => _isUploadingImage = false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await _chat.sendMessage(widget.args.peerId, '📷 Photo', auth.currentUser,
            imageUrl: url);
      } else {
        final bytes = await picked.readAsBytes();
        _scrollToBottom();
        await _chat.sendPhoto(widget.args.peerId, bytes);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isUploadingImage = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e is E2eeException ? e.message : 'Could not send the photo. $e'),
      ));
    }
  }

  // ── Share location ──────────────────────────────────────────────────────────

  Future<void> _shareLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = widget.args.name;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share your location?'),
        content: Text(
          '$name will see exactly where you are right now and can open it on the '
          'map. It is sent end-to-end encrypted and is not updated afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Share')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 2),
      content: Text('Getting your location…'),
    ));
    final res = await LocationService.instance.locate();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (!res.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (res.status) {
          LocationStatus.serviceOff => 'Turn on location (GPS) to share it.',
          LocationStatus.denied ||
          LocationStatus.deniedForever =>
            'Allow location access in Settings to share it.',
          _ => 'Could not get your location. Please try again.',
        }),
      ));
      return;
    }
    final fix = res.fix!;
    try {
      await _chat.sendLocation(widget.args.peerId, fix.lat, fix.lng);
      _scrollToBottom();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_sendError(e))));
    }
  }

  void _openOnMap(SharedLocation loc, {required bool mine}) {
    HapticFeedback.selectionClick();
    // Home switches to the Maps tab, closes this chat and drops the pin.
    AppNavigation.showOnMap(MapFocusTarget(
      lat: loc.lat,
      lng: loc.lng,
      label: mine ? 'My shared location' : "${widget.args.name}'s location",
    ));
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Voice (English / Hindi) ─────────────────────────────────────────────────

  Future<void> _startVoice([VoiceLang? lang]) async {
    if (lang != null) _voiceLang = lang;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _voiceActive = true);
    final result = await _voice.start(_voiceLang, onFinal: _onVoiceFinal);
    if (!mounted) return;
    if (result != VoiceStartResult.started) {
      setState(() => _voiceActive = false);
      _showVoiceProblem(result);
    }
  }

  Future<void> _switchVoiceLang(VoiceLang lang) async {
    if (lang == _voiceLang) return;
    await _voice.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _startVoice(lang);
  }

  void _onVoiceFinal(String text) {
    if (!mounted) return;
    setState(() => _voiceActive = false);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_voiceLang == VoiceLang.hindi
            ? 'कुछ सुनाई नहीं दिया। फिर से कोशिश करें।'
            : "Didn't catch that. Tap the mic and try again."),
      ));
      return;
    }
    final current = _textController.text;
    final joined = current.trim().isEmpty ? text : '${current.trimRight()} $text';
    final limited = joined.length > _maxChars ? joined.substring(0, _maxChars) : joined;
    _textController.value = TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
    _onTextChanged(limited);
  }

  void _showVoiceProblem(VoiceStartResult result) {
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case VoiceStartResult.permissionDenied:
        messenger.showSnackBar(SnackBar(
          content: const Text('Allow microphone and speech access to use voice typing.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ));
      case VoiceStartResult.languageMissing:
        messenger.showSnackBar(SnackBar(
          content: Text(_voiceLang == VoiceLang.hindi
              ? 'Hindi voice typing is not installed on this phone. Install it in '
                  'Settings → Google → Voice → Languages, then try again.'
              : 'English voice typing is not available on this phone.'),
          duration: const Duration(seconds: 6),
        ));
      case VoiceStartResult.unavailable:
        messenger.showSnackBar(const SnackBar(
          content: Text('Speech recognition is not available on this phone. '
              'Install / enable the Google app and try again.'),
          duration: Duration(seconds: 6),
        ));
      default:
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not start voice typing. Please try again.')),
        );
    }
  }

  // ── Sheets / dialogs ────────────────────────────────────────────────────────

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
                    final t = _textController.text + emojis[index];
                    _textController.value = TextEditingValue(
                      text: t,
                      selection: TextSelection.collapsed(offset: t.length),
                    );
                    _onTextChanged(t);
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
              subtitle: Text(
                _isSystem
                    ? 'Uploaded securely to Rovlo cloud'
                    : 'Encrypted on your phone before it is uploaded',
                style: _pickerHintStyle,
              ),
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
            if (!_isSystem)
              ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFFE53935)),
                title: const Text('Share my location'),
                subtitle: Text(
                  '${widget.args.name} can open it on the Rovlo map',
                  style: _pickerHintStyle,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareLocation();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEncryptionInfo() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: OnlineDot.green),
                const SizedBox(width: 10),
                Text('End-to-end encrypted',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Messages and photos in this chat are locked on your phone and can only '
              'be unlocked on ${widget.args.name}\'s phone. Not even Rovlo can read them.',
              style: TextStyle(color: ctx.rovlo.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
            Text('SAFETY CODE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: ctx.rovlo.textSecondary)),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: E2eeService.instance.safetyCode(widget.args.peerId),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    snap.error is E2eeException
                        ? (snap.error as E2eeException).message
                        : 'Not available right now.',
                    style: TextStyle(color: ctx.rovlo.textSecondary),
                  );
                }
                return SelectableText(
                  snap.data!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Compare this code with ${widget.args.name} in person or on a call. '
              'If it matches on both phones, nobody is listening in.',
              style: TextStyle(fontSize: 12, color: ctx.rovlo.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  void _showBytesPreview(Uint8List bytes) {
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
              child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
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

  void _openPeerProfile() {
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
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final textSecColor = context.rovlo.textSecondary;

    final chatProvider = context.watch<ChatProvider>();
    final conv = chatProvider.getConversation(widget.args.peerId);
    final messages = conv?.messages ?? [];

    // Follow new messages (mine and theirs).
    if (messages.length != _lastCount) {
      final grew = messages.length > _lastCount;
      _lastCount = messages.length;
      if (grew) _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _openPeerProfile,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
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
                  if (!_isSystem)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: OnlineDot(userId: widget.args.peerId, size: 12),
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
                    _buildStatusLine(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!_isSystem)
            IconButton(
              tooltip: 'Encryption',
              icon: const Icon(Icons.lock_outline, size: 20),
              onPressed: _showEncryptionInfo,
            ),
        ],
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
                      onPressed: () => setState(() => _showSafetyBanner = false),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildMessageList(messages, isDark, textSecColor)),
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
            _buildComposer(isDark, primaryPeach, textSecColor),
          ],
        ),
      ),
    );
  }

  /// "typing…" / "Online" / "Offline" under the name.
  Widget _buildStatusLine() {
    if (_isSystem) {
      return Text(
        _isSupport ? 'Support team' : 'Travel Assistant Bot',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _peerTyping,
      builder: (context, typing, _) => OnlineBuilder(
        userId: widget.args.peerId,
        builder: (context, online) {
          final text = typing ? 'typing…' : (online ? 'Online' : 'Offline');
          final color = (typing || online) ? OnlineDot.green : context.rovlo.textSecondary;
          return Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              fontStyle: typing ? FontStyle.italic : FontStyle.normal,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, bool isDark, Color textSecColor) {
    if (_isSupport && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            'Hi! 👋 How can we help?\nSend a message or a photo and the Rovlo team will reply here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecColor, height: 1.5),
          ),
        ),
      );
    }

    final hasHeader = !_isSystem;
    return ValueListenableBuilder<bool>(
      valueListenable: _peerTyping,
      builder: (context, typing, _) {
        final extra = (typing ? 1 : 0);
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length + (hasHeader ? 1 : 0) + extra,
          itemBuilder: (context, index) {
            if (hasHeader) {
              if (index == 0) return _buildEncryptionNotice(textSecColor);
              index -= 1;
            }
            if (index >= messages.length) return _buildTypingBubble(isDark);
            return _buildMessage(messages[index], isDark, textSecColor);
          },
        );
      },
    );
  }

  Widget _buildEncryptionNotice(Color textSecColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: GestureDetector(
          onTap: _showEncryptionInfo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: OnlineDot.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 13, color: OnlineDot.green),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Messages are end-to-end encrypted. Tap to learn more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: textSecColor, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: CachedNetworkImageProvider(widget.args.imageUrl),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFEBEBEB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: context.rovlo.textSecondary,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 160).ms)
                    .fade(begin: 0.3, end: 1, duration: 450.ms)
                    .moveY(begin: 0, end: -3, duration: 450.ms);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg, bool isDark, Color textSecColor) {
    final textColor = msg.isMe ? Colors.white : (isDark ? Colors.white : AppColors.lightTextPrimary);
    final showCaption = msg.text.isNotEmpty && msg.text != '📷 Photo';

    Widget content;
    if (msg.undecryptable) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: textColor.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "This message can't be read on this phone.",
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    } else if (msg.location != null) {
      content = _buildLocationCard(msg, textColor);
    } else if (msg.hasImage) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: msg.hasEncryptedImage ? null : () => _showImagePreview(msg.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
                child: msg.hasEncryptedImage
                    ? _SecurePhoto(
                        key: ValueKey(msg.id ?? identityHashCode(msg)),
                        message: msg,
                        onOpen: _showBytesPreview,
                      )
                    : _buildImageWidget(msg.imageUrl!),
              ),
            ),
          ),
          if (showCaption) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SelectableText(
                msg.text,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
          ],
        ],
      );
    } else {
      content = SelectableText(
        msg.text,
        style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
      );
    }

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
                  padding: msg.hasImage && !msg.undecryptable
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
                  child: content,
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
                      _buildTicks(msg.status, textSecColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ChatMessage msg, Color textColor) {
    final loc = msg.location!;
    return GestureDetector(
      onTap: () => _openOnMap(loc, mine: msg.isMe),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: msg.isMe ? 0.22 : 0.0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Color(0xFFE53935), size: 30),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.isMe ? 'You shared your location' : 'Shared location',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to view on map',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// sending 🕓 · sent ✓ · delivered ✓✓ · read ✓✓ (blue)
  Widget _buildTicks(MessageStatus status, Color textSecColor) {
    final grey = textSecColor.withValues(alpha: 0.7);
    return switch (status) {
      MessageStatus.sending => Icon(Icons.access_time, size: 12, color: grey),
      MessageStatus.sent => Icon(Icons.done, size: 13, color: grey),
      MessageStatus.delivered => Icon(Icons.done_all, size: 13, color: grey),
      MessageStatus.read => const Icon(Icons.done_all, size: 13, color: _readBlue),
    };
  }

  // ── Composer ────────────────────────────────────────────────────────────────

  Widget _buildComposer(bool isDark, Color primaryPeach, Color textSecColor) {
    return SafeArea(
      top: false,
      bottom: context.keyboardInset == 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _voiceActive
              ? _buildVoicePanel(isDark, primaryPeach, textSecColor)
              : _buildInputRow(isDark, primaryPeach, textSecColor),
        ),
      ),
    );
  }

  Widget _buildInputRow(bool isDark, Color primaryPeach, Color textSecColor) {
    return Row(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.sentiment_satisfied_alt_outlined, color: textSecColor),
                  onPressed: _showEmojiPicker,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 14),
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    inputFormatters: [LengthLimitingTextInputFormatter(_maxChars)],
                    onChanged: _onTextChanged,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      // One line: a longer hint wrapped when the icons took the width.
                      hintText: 'Message',
                      hintMaxLines: 1,
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
                  tooltip: 'Voice typing (English / हिन्दी)',
                  icon: Icon(Icons.mic_none_rounded, color: textSecColor),
                  onPressed: _startVoice,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
                ),
                IconButton(
                  icon: Icon(Icons.attach_file, color: textSecColor),
                  onPressed: _showAttachmentPicker,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
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
    );
  }

  /// Shown while the microphone is listening: language switch, live words,
  /// Cancel / Done. The recognised text lands in the message box so it can be
  /// checked before sending.
  Widget _buildVoicePanel(bool isDark, Color primaryPeach, Color textSecColor) {
    return Container(
      key: const ValueKey('voice'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryPeach.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final lang in VoiceLang.values) ...[
                ChoiceChip(
                  label: Text(lang.label),
                  selected: _voiceLang == lang,
                  onSelected: (_) => _switchVoiceLang(lang),
                  selectedColor: primaryPeach.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _voiceLang == lang ? primaryPeach : textSecColor,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: _voice.transcript,
            builder: (context, words, _) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 110),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  words.isEmpty
                      ? (_voiceLang == VoiceLang.hindi ? 'बोलिए… सुन रहा हूँ' : 'Listening… speak now')
                      : words,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: words.isEmpty ? FontWeight.w500 : FontWeight.w600,
                    color: words.isEmpty ? textSecColor : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  await _voice.cancel();
                  if (mounted) setState(() => _voiceActive = false);
                },
                child: const Text('Cancel'),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: _voice.listening,
                builder: (context, on, _) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: on ? Colors.red.shade400 : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.18, duration: 650.ms, curve: Curves.easeInOut),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _voice.stop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPeach,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An encrypted photo: shows my own copy instantly while it uploads, otherwise
/// downloads the ciphertext and decrypts it on this phone (cached per session).
class _SecurePhoto extends StatefulWidget {
  const _SecurePhoto({super.key, required this.message, required this.onOpen});

  final ChatMessage message;
  final void Function(Uint8List bytes) onOpen;

  @override
  State<_SecurePhoto> createState() => _SecurePhotoState();
}

class _SecurePhotoState extends State<_SecurePhoto> {
  Future<Uint8List>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Uint8List> _load() {
    final chat = context.read<ChatProvider>();
    final pending = chat.pendingPhoto(widget.message);
    if (pending != null) return Future.value(pending);
    return chat.photoBytes(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final sending = widget.message.status == MessageStatus.sending;
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return GestureDetector(
            onTap: () => setState(() => _future = _load()),
            child: Container(
              width: 200,
              height: 140,
              color: Colors.black12,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Colors.grey),
                  const SizedBox(height: 6),
                  Text(
                    snap.error is E2eeException
                        ? "Can't open this photo"
                        : 'Tap to retry',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Container(
            width: 200,
            height: 140,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 8),
                Icon(Icons.lock, size: 14, color: Colors.grey),
              ],
            ),
          );
        }
        final bytes = snap.data!;
        return GestureDetector(
          onTap: sending ? null : () => widget.onOpen(bytes),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              if (sending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
