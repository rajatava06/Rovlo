import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

/// Profile tab: identity header, travel interests, and links to Settings,
/// the Admin Panel (admins only) and sign-out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final user = provider.currentUser;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Text('Profile',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, Routes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Header(user: user).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 24),
          if (user.travelInterests.isNotEmpty) ...[
            _SectionLabel('Travel interests'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in user.travelInterests)
                  Chip(
                    label: Text(interest),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    side: BorderSide.none,
                    labelStyle: const TextStyle(color: AppColors.primaryDark),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          _SectionLabel('Account'),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings & appearance',
            onTap: () => Navigator.pushNamed(context, Routes.settings),
          ),
          _MenuTile(
            icon: Icons.notifications_none,
            label: 'Notifications',
            onTap: () => _soon(context),
          ),
          _MenuTile(
            icon: Icons.help_outline,
            label: 'Help & support',
            onTap: () => _soon(context),
          ),
          if (provider.isAdmin) ...[
            const SizedBox(height: 24),
            _SectionLabel('Admin'),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin panel',
              highlight: true,
              onTap: () => Navigator.pushNamed(context, Routes.admin),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, provider),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign out',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, AuthProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await provider.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (r) => false);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child: Text(user.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user.email ?? user.phoneNumber ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13)),
                if (user.gender != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(user.gender!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.rovlo.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          leading: Icon(icon,
              color: highlight ? AppColors.primary : null),
          title: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: highlight ? AppColors.primaryDark : null)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}
