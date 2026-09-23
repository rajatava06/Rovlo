import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/keyboard_inset.dart';
import '../../providers/chat_provider.dart';
import '../../services/media_service.dart';
import '../../services/support_service.dart';

String _timeLabel(DateTime t) {
  final now = DateTime.now();
  if (now.difference(t).inHours < 24 && now.day == t.day) return DateFormat('h:mm a').format(t);
  if (now.difference(t).inDays < 7) return DateFormat('EEE').format(t);
  return DateFormat('d MMM').format(t);
}

/// Agent inbox: every customer who wrote to Rovlo Support, newest first.
/// Shown as a tab in the Admin panel for support agents only.
class SupportInbox extends StatefulWidget {
  const SupportInbox({super.key});

  @override
  State<SupportInbox> createState() => _SupportInboxState();
}

class _SupportInboxState extends State<SupportInbox> {
  List<SupportThread> _threads = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<SupportMessage>? _sub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    // New messages arrive live: refresh the list shortly after each one.
    _sub = context.read<ChatProvider>().supportStream.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await SupportService.instance.threads();
      if (!mounted) return;
      setState(() {
        _threads = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the support inbox.\n($e)';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSec = context.rovlo.textSecondary;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_threads.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.support_agent, size: 52, color: textSec),
            const SizedBox(height: 12),
            Center(
              child: Text('No support messages yet.', style: TextStyle(color: textSec)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = _threads[i];
          final needsReply = !t.lastFromSupport;
          return Material(
            color: context.rovlo.card,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupportThreadScreen(thread: t)),
                );
                if (mounted) _load(silent: true);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(t.photoUrl!)
                          : null,
                      child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                          ? Text(
                              t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
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
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              if (needsReply) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NEEDS REPLY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${t.lastFromSupport ? 'You: ' : ''}${t.lastBody}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: needsReply ? null : textSec,
                              fontWeight: needsReply ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeLabel(t.lastAt),
                          style: TextStyle(fontSize: 11, color: textSec),
                        ),
                        const SizedBox(height: 6),
                        if (t.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${t.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One customer conversation, from the agent's side. Text and images only.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key, required this.thread});

  final SupportThread thread;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _uploading = false;
  RealtimeChannel? _channel;

  SupportService get _svc => SupportService.instance;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _svc.subscribe(
      'support-thread-${widget.thread.userId}',
      (m) {
        if (!mounted || _messages.any((x) => x.id == m.id)) return;
        setState(() => _messages = [..._messages, m]);
        _scrollToBottom();
        if (!m.fromSupport) _svc.markThreadRead(widget.thread.userId);
      },
      threadUser: widget.thread.userId,
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _svc.threadMessages(widget.thread.userId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
      unawaited(_svc.markThreadRead(widget.thread.userId));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send({String? imageUrl}) async {
    final text = _text.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    final messenger = ScaffoldMessenger.of(context);
    _text.clear();
    try {
      await _svc.sendAsAgent(widget.thread.userId, text: text, imageUrl: imageUrl);
    } catch (_) {
      _text.text = text;
      messenger.showSnackBar(const SnackBar(content: Text('Reply not sent. Try again.')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (picked == null) return;
      setState(() => _uploading = true);
      final url = await MediaService.instance.uploadXFile(picked, bucket: 'chat-media');
      await _send(imageUrl: url);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not send the photo.')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _attach() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = context.rovlo.textSecondary;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.thread.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.thread.email != null)
              Text(widget.thread.email!, style: TextStyle(fontSize: 11, color: textSec)),
          ],
        ),
      ),
      body: KeyboardAvoiding(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m.fromSupport; // agent's own replies on the right
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: m.imageUrl != null && m.imageUrl!.isNotEmpty
                                ? const EdgeInsets.all(4)
                                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: mine
                                  ? primary
                                  : (isDark ? AppColors.darkCard : const Color(0xFFEBEBEB)),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 2),
                                bottomRight: Radius.circular(mine ? 2 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: m.imageUrl!,
                                      width: 220,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          const SizedBox(width: 220, height: 140),
                                      errorWidget: (_, __, ___) => const SizedBox(
                                        width: 220,
                                        height: 100,
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                if (m.body.isNotEmpty)
                                  Padding(
                                    padding: m.imageUrl != null && m.imageUrl!.isNotEmpty
                                        ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
                                        : EdgeInsets.zero,
                                    child: Text(
                                      m.body,
                                      style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black87),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('d MMM, h:mm a').format(m.createdAt),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: mine ? Colors.white70 : textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_uploading) const LinearProgressIndicator(minHeight: 2),
            SafeArea(
              top: false,
              bottom: context.keyboardInset == 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _uploading ? null : _attach,
                      icon: Icon(Icons.attach_file, color: textSec),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Reply to customer…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                        child: const Icon(Icons.send, color: Colors.white, size: 19),
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
