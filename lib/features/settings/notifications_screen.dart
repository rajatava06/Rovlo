import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/push_notification_service.dart';

/// Settings → Notifications: one switch for push notifications on this device,
/// plus a plain-language list of what Rovlo sends.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final PushNotificationService _push = PushNotificationService();
  bool _enabled = true;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _push.loadPreference().then((v) {
      if (mounted) {
        setState(() {
          _enabled = v;
          _loading = false;
        });
      }
    });
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _enabled = on; // optimistic
    });
    final ok = await _push.setEnabled(on);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _enabled = !on;
    });
    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(on
            ? 'Push notifications are on 🔔'
            : 'Push notifications are off. You can still see updates in the bell on Discover.'),
      ));
    } else if (on) {
      messenger.showSnackBar(SnackBar(
        content: const Text(
            'Notifications are blocked for Rovlo. Allow them in your phone settings.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => Geolocator.openAppSettings(),
        ),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not switch off. Check your connection and try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rovlo = context.rovlo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: rovlo.card,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Push notifications',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _enabled ? 'On for this device' : 'Off for this device',
                style: TextStyle(color: rovlo.textSecondary),
              ),
              value: _enabled,
              onChanged: (_loading || _busy) ? null : _toggle,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'WHAT WE SEND YOU',
            style: TextStyle(
              color: rovlo.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          const _TypeTile(
            icon: Icons.favorite_border,
            title: 'Likes & matches',
            body: 'When someone likes you, and when a like turns into a match so you can start chatting.',
          ),
          const _TypeTile(
            icon: Icons.support_agent_outlined,
            title: 'Support replies',
            body: 'When the Rovlo Support team answers your message.',
          ),
          const _TypeTile(
            icon: Icons.campaign_outlined,
            title: 'Rovlo announcements',
            body: 'Important news, safety alerts, app updates and the occasional offer from the Rovlo team.',
          ),
          const SizedBox(height: 12),
          Text(
            'We never send ads from other companies. Turning push off stops these '
            'alerts on this device only. Likes, matches and announcements still '
            'appear in the bell on the Discover screen.',
            style: TextStyle(color: rovlo.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final rovlo = context.rovlo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(color: rovlo.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
