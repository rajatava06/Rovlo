import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../home/chat_room_screen.dart';

/// Help & support: the in-app Rovlo Support chat, or e-mail.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String supportEmail = 'hellorovlo2026@gmail.com';

  void _openSupportChat(BuildContext context) {
    final chat = context.read<ChatProvider>();
    chat.ensureConversation(
      peerId: kSupportId,
      name: 'Rovlo Support',
      imageUrl: '',
      isVerified: true,
    );
    chat.markAsRead(kSupportId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatRoomScreen(
          args: ChatRoomArgs(
            peerId: kSupportId,
            name: 'Rovlo Support',
            imageUrl: '',
            isVerified: true,
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Rovlo support'},
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      messenger.showSnackBar(
        const SnackBar(content: Text('No mail app found. Email address copied.')),
      );
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    messenger.showSnackBar(const SnackBar(content: Text('Email address copied')));
  }

  @override
  Widget build(BuildContext context) {
    final rovlo = context.rovlo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & support', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Need a hand? Reach the Rovlo team in whichever way suits you.',
            style: TextStyle(color: rovlo.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          _OptionCard(
            icon: Icons.support_agent_outlined,
            title: 'Chat with Rovlo Support',
            body: 'The fastest way. Send a message or photo and the team replies right here in the app.',
            action: 'Open support chat',
            onTap: () => _openSupportChat(context),
            highlight: true,
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.mail_outline,
            title: 'Email us',
            body: supportEmail,
            action: 'Send an email',
            onTap: () => _sendEmail(context),
            secondaryAction: 'Copy address',
            onSecondaryTap: () => _copyEmail(context),
          ),
          const SizedBox(height: 20),
          Text(
            'Reporting a safety problem or an account issue? Include your name and '
            'what happened so we can help quickly.',
            style: TextStyle(color: rovlo.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
    this.secondaryAction,
    this.onSecondaryTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  final String? secondaryAction;
  final VoidCallback? onSecondaryTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final rovlo = context.rovlo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: highlight ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: rovlo.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          // Wrap (not Row): "Send an email" + "Copy address" don't fit side by side
          // on narrow phones and overflowed by a couple of pixels.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  // The app theme makes buttons full-width; inside a Row that
                  // has no width to fill and the whole screen failed to lay out.
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(action,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (secondaryAction != null)
                TextButton(onPressed: onSecondaryTap, child: Text(secondaryAction!)),
            ],
          ),
        ],
      ),
    );
  }
}
