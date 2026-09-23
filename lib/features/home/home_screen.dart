import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import 'explore_tab.dart';
import 'profile_tab.dart';
import 'maps_tab.dart';
import 'chats_tab.dart';
import 'hot_tab.dart';

/// Main authenticated shell with iOS-style floating oval bottom navigation bar.
///
/// Features:
/// - Hide on scroll down, reappear on scroll up
/// - Translucent frosted glass effect with blue tint
/// - Animated slider indicator between tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 2; // Default to Discover (index 2)
  bool _isNavVisible = true;
  StreamSubscription<String>? _notificationSub;
  StreamSubscription? _adminNotifSub;
  String? _bannerText;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().refreshCurrentUser(),
    );

    // Chat notification banner
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _notificationSub = chatProvider.notificationStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _bannerText = msg;
        _showBanner = true;
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _showBanner = false);
      });
    });

    // Admin push notification banner
    _adminNotifSub = NotificationService().onNotification.listen((notif) {
      if (!mounted) return;
      setState(() {
        _bannerText = '${notif.title}: ${notif.body}';
        _showBanner = true;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _showBanner = false);
      });
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _adminNotifSub?.cancel();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Navbar remains fixed (always visible) on Discover tab (index 2)
    if (_index == 2) {
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
      return false;
    }

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isNavVisible) {
          setState(() => _isNavVisible = false);
        }
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_isNavVisible) {
          setState(() => _isNavVisible = true);
        }
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels <= 10 && !_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const MapsTab(),
      const HotTab(),
      const ExploreTab(),
      const ChatsTab(),
      const ProfileTab(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue =
        isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final chatProvider = context.watch<ChatProvider>();
    final hasUnread = chatProvider.hasUnreadMessages;

    return Scaffold(
      body: Stack(
        children: [
          // ── Tab Content with Scroll Detection ────────────────────────────
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: _index == 0
                  ? const MapsTab()
                  : SafeArea(
                      top: true,
                      bottom: false,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
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
          ),

          // ── Notification Banner ──────────────────────────────────────────
          if (_showBanner && _bannerText != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryBlue.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble, color: primaryBlue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'New Notification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _bannerText!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.rovlo.textSecondary),
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
                          onPressed: () =>
                              setState(() => _showBanner = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .slideY(
                    begin: -1.0,
                    end: 0.0,
                    duration: 300.ms,
                    curve: Curves.easeOutQuad)
                .fadeIn(),

          // ── iOS Oval Floating Bottom Navbar (Pop down on scroll) ────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 8,
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 2),
              child: AnimatedSlide(
                offset: _isNavVisible ? Offset.zero : const Offset(0, 1.6),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: _isNavVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _IosOvalNavBar(
                    currentIndex: _index,
                    hasUnread: hasUnread,
                    onTap: (i) => setState(() {
                      _index = i;
                      if (i == 2) _isNavVisible = true;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style Floating Oval Nav Bar with translucent blue tint and slider indicator
// ─────────────────────────────────────────────────────────────────────────────

class _IosOvalNavBar extends StatefulWidget {
  const _IosOvalNavBar({
    required this.currentIndex,
    required this.hasUnread,
    required this.onTap,
  });

  final int currentIndex;
  final bool hasUnread;
  final ValueChanged<int> onTap;

  @override
  State<_IosOvalNavBar> createState() => _IosOvalNavBarState();
}

class _IosOvalNavBarState extends State<_IosOvalNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnim;
  int _prevIndex = 2;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Maps'),
    _NavItem(
        icon: Icons.whatshot_outlined,
        activeIcon: Icons.whatshot,
        label: 'Hot'),
    _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Discover'),
    _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chats'),
    _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim =
        Tween<double>(begin: widget.currentIndex.toDouble(),
                      end: widget.currentIndex.toDouble())
            .animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void didUpdateWidget(_IosOvalNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _slideAnim = Tween<double>(
        begin: _prevIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOutCubic,
      ));
      _slideController.forward(from: 0);
      _prevIndex = widget.currentIndex;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBlue =
        isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    // Translucent background with subtle blue tint
    final bgColor = isDark
        ? const Color(0xFF0A192F).withValues(alpha: 0.82)
        : AppColors.lightBackground.withValues(alpha: 0.88);

    final borderColor = isDark
        ? AppColors.primaryVibrantDark.withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.20);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: activeBlue.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;

              return Stack(
                children: [
                  // ── Animated sliding indicator ─────────────────────────────
                  AnimatedBuilder(
                    animation: _slideAnim,
                    builder: (context, _) {
                      final left =
                          _slideAnim.value * itemWidth + itemWidth * 0.08;
                      final indicatorWidth = itemWidth * 0.84;
                      return Positioned(
                        left: left,
                        top: 4,
                        bottom: 4,
                        width: indicatorWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                activeBlue.withValues(alpha: isDark ? 0.22 : 0.18),
                                activeBlue.withValues(alpha: isDark ? 0.12 : 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: activeBlue.withValues(alpha: isDark ? 0.35 : 0.28),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeBlue.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // ── Nav items ──────────────────────────────────────────────
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      final isSelected = i == widget.currentIndex;
                      final showBadge =
                          item.label == 'Chats' && widget.hasUnread;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (widget.currentIndex != i) {
                              HapticFeedback.selectionClick();
                            }
                            widget.onTap(i);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.10 : 1.0,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      isSelected ? item.activeIcon : item.icon,
                                      size: 20,
                                      color: isSelected
                                          ? activeBlue
                                          : context.rovlo.textSecondary,
                                    ),
                                  ),
                                  if (showBadge)
                                    Positioned(
                                      top: -2,
                                      right: -4,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: activeBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.darkSurface
                                                : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? activeBlue
                                      : context.rovlo.textSecondary,
                                ),
                                child: Text(item.label),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}


