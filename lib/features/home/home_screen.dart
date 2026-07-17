import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'explore_tab.dart';
import 'profile_tab.dart';
import 'maps_tab.dart';
import 'matches_tab.dart';
import 'chats_tab.dart';

/// Main authenticated shell with a custom 5-tab bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 2; // Default to Discover (index 2)

  @override
  void initState() {
    super.initState();
    // Ensure profile data is fresh when landing on Home.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().refreshCurrentUser(),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    bool isMiddle = false,
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
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
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
      const MatchesTab(),
      const ExploreTab(),
      const ChatsTab(),
      const ProfileTab(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedSwitcher(
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
      bottomNavigationBar: Container(
        height: 76,
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
                  icon: Icons.favorite_border,
                  selectedIcon: Icons.favorite,
                  label: 'Matches',
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
