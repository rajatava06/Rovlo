import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

/// Settings — available after login. Primary feature: dark / light / system
/// appearance, persisted across launches.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionLabel('Appearance'),
          const SizedBox(height: 12),
          _QuickDarkToggle(theme: theme),
          const SizedBox(height: 16),
          _ThemeModeCard(theme: theme),
          const SizedBox(height: 28),
          const _SectionLabel('About'),
          const SizedBox(height: 12),
          const _InfoTile(
            icon: Icons.info_outline,
            title: 'Version',
            trailing: '1.0.0',
          ),
          _InfoTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () {},
          ),
          _InfoTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('${AppConstants.appName} • ${AppConstants.tagline}',
                style: TextStyle(color: context.rovlo.textSecondary)),
          ),
        ],
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
        title: const Text('Dark mode',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(isDark ? 'On' : 'Off',
            style: TextStyle(color: context.rovlo.textSecondary)),
        secondary: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              RotationTransition(turns: anim, child: child),
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
                      color: theme.mode == mode
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          color: theme.mode == mode
                              ? AppColors.primary
                              : context.rovlo.textSecondary),
                      const SizedBox(height: 8),
                      Text(label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.mode == mode
                                ? AppColors.primaryDark
                                : null,
                          )),
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
              ? Text(trailing!,
                  style: TextStyle(color: context.rovlo.textSecondary))
              : (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
          onTap: onTap,
        ),
      ),
    );
  }
}
