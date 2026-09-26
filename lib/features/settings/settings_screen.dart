import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

/// Settings screen with Theme controls and separate Cookie Policy & Privacy Policy modals.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionLabel('Appearance'),
          const SizedBox(height: 12),
          _QuickDarkToggle(theme: theme),
          const SizedBox(height: 16),
          _ThemeModeCard(theme: theme),
          const SizedBox(height: 28),
          const _SectionLabel('Legal & Privacy'),
          const SizedBox(height: 12),
          const _InfoTile(
            icon: Icons.info_outline,
            title: 'Version',
            trailing: '1.0.0 (Release Build)',
          ),
          _InfoTile(
            icon: Icons.cookie_outlined,
            title: 'Cookie Policy',
            onTap: () => _showCookiePolicy(context),
          ),
          _InfoTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _showPrivacyPolicy(context),
          ),
          _InfoTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => _showTerms(context),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} • ${AppConstants.tagline}',
              style: TextStyle(color: context.rovlo.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showCookiePolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const Row(
              children: [
                Icon(Icons.cookie, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                // Expanded: the long title used to run off the right edge.
                Expanded(
                  child: Text(
                    'Cookie & Local Storage Policy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Last Updated: July 2026\n\n'
              'Rovlo uses local storage, session storage, and cookies to ensure you get the best travel companion experience. This policy explains what information we store locally on your device.\n\n'
              '1. Essential Session Cookies:\n'
              'We save your login token, active session status, and user profile data in encrypted local storage so you stay securely logged in across app restarts without re-entering credentials.\n\n'
              '2. User Preferences:\n'
              'Your selected theme (Dark Mode / Light Mode), travel interests, saved profiles, and notification preferences are saved directly on your device.\n\n'
              '3. Geolocation & Maps:\n'
              'When you allow location access, your last known geographic coordinates are temporarily cached locally to load nearby travelers on the map quickly.\n\n'
              '4. Managing Your Preferences:\n'
              'You can clear your local cache or log out anytime from the Account menu. Clearing your data will reset your local preferences.',
              style: TextStyle(height: 1.6, color: context.rovlo.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: AppColors.primary, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your privacy is top priority at Rovlo.\n\n'
              '• Data Collection: We collect account details (name, email, age, profile photos) and optional location data to connect you with nearby verified travelers.\n'
              '• End-to-End Safety: Messages and emergency SOS contacts are stored securely.\n'
              '• Control & Pause Account: You can pause your account at any time to hide your profile from public discovery or delete your account permanently.\n'
              '• Third-Party Sharing: We never sell your personal information or location data to third parties.\n\n'
              'For full legal inquiries, contact privacy@rovlo.com.',
              style: TextStyle(height: 1.6, color: context.rovlo.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const Text(
              'Terms & Conditions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'By using Rovlo, you agree to respect local laws, treat fellow travelers with courtesy, and follow our community guidelines. Account abuse, harassment, or fake profiles will result in an immediate permanent ban.',
              style: TextStyle(height: 1.6, color: context.rovlo.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDarkToggle extends StatelessWidget {
  const _QuickDarkToggle({required this.theme});
  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(isDark ? 'On' : 'Off', style: TextStyle(color: context.rovlo.textSecondary)),
        secondary: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            key: ValueKey(isDark),
            color: AppColors.primary,
          ),
        ),
        value: isDark,
        onChanged: (v) => theme.toggleDark(v),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.theme});
  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final options = <(ThemeMode, IconData, String)>[
      (ThemeMode.light, Icons.light_mode, 'Light'),
      (ThemeMode.dark, Icons.dark_mode, 'Dark'),
      (ThemeMode.system, Icons.brightness_auto, 'System'),
    ];
    return Row(
      children: [
        for (final (mode, icon, label) in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => theme.setMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: theme.mode == mode
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : context.rovlo.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: theme.mode == mode ? AppColors.primary : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: theme.mode == mode ? AppColors.primary : context.rovlo.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.mode == mode ? AppColors.primaryDark : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: trailing != null
              ? Text(trailing!, style: TextStyle(color: context.rovlo.textSecondary))
              : (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
          onTap: onTap,
        ),
      ),
    );
  }
}
