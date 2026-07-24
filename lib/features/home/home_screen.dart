import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'explore_tab.dart';
import 'profile_tab.dart';
import 'maps_tab.dart';
import 'chats_tab.dart';

/// Main authenticated shell with a custom 5-tab bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 2; // Default to Discover (index 2)
  StreamSubscription<String>? _notificationSub;
  String? _bannerText;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    // Ensure profile data is fresh when landing on Home.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().refreshCurrentUser(),
    );

    // Listen for incoming dynamic notifications from ChatProvider
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _notificationSub = chatProvider.notificationStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _bannerText = msg;
        _showBanner = true;
      });
      // Auto hide notification banner after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _showBanner = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    bool isMiddle = false,
    bool showDot = false,
  }) {
    final isSelected = _index == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final inactiveColor = context.rovlo.textSecondary;

    if (isMiddle) {
      return GestureDetector(
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 62 : 54,
              height: isSelected ? 44 : 38,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : (isDark ? AppColors.darkCard : AppColors.secondary),
                borderRadius: BorderRadius.circular(22),
                border: isSelected
                    ? Border.all(
                        color: isDark ? Colors.white : AppColors.elementBlack,
                        width: 1.5,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                size: isSelected ? 26 : 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                  if (showDot)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primaryVibrantDark : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const MapsTab(),
      const _HotComingSoon(),
      const ExploreTab(),
      const ChatsTab(),
      const ProfileTab(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final chatProvider = context.watch<ChatProvider>();
    final hasUnread = chatProvider.hasUnreadMessages;

    return Scaffold(
      body: Stack(
        children: [
          // If Maps tab (index 0), render full screen without top SafeArea padding
          Positioned.fill(
            child: _index == 0
                ? const MapsTab()
                : SafeArea(
                    top: true,
                    bottom: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: tabs[_index],
                      ),
                    ),
                  ),
          ),

          // ── In-App Heads-up Notification Banner ──
          if (_showBanner && _bannerText != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryPeach.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble, color: primaryPeach, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'New Notification',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _bannerText!,
                                style: TextStyle(fontSize: 12, color: context.rovlo.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _showBanner = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: -1.0, end: 0.0, duration: 300.ms, curve: Curves.easeOutQuad).fadeIn(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 88,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map,
                  label: 'Maps',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.whatshot_outlined,
                  selectedIcon: Icons.whatshot,
                  label: 'Hot',
                ),
                // Discover (Highlighted)
                Expanded(
                  child: _buildNavItem(
                    index: 2,
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore,
                    label: 'Discover',
                    isMiddle: true,
                  ),
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline,
                  selectedIcon: Icons.chat_bubble,
                  label: 'Chats',
                  showDot: hasUnread,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotComingSoon extends StatelessWidget {
  const _HotComingSoon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryPeach.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.whatshot, color: primaryPeach, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Hot Profiles',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Instant trending matches and hot explorer recommendations are coming soon!',
                style: TextStyle(
                  color: context.rovlo.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
