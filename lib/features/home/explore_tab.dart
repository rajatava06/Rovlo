import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/rovlo_loader.dart';
import '../../core/widgets/rovlo_logo.dart';
import '../../models/admin_notification.dart';
import '../../models/traveler.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../services/traveler_repository.dart';
import 'traveler_profile_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  bool _isNearMe = true;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _suggestions = [];
  String? _selectedLocation;
  String _selectedWeek = '2nd Week';
  String _selectedMonth = 'Oct';
  String _selectedYear = '2026';

  String _getFormattedDateCompact() {
    final wkShort = _selectedWeek
        .replaceAll(' Week', 'W')
        .replaceAll('st', '')
        .replaceAll('nd', '')
        .replaceAll('rd', '')
        .replaceAll('th', '');
    return '$_selectedMonth $wkShort';
  }

  String get _selectedTravelDate {
    return '$_selectedWeek, $_selectedMonth $_selectedYear';
  }

  // Real notifications: admin broadcasts + new matches (from the database).
  final List<Map<String, dynamic>> _notifications = [];

  final TravelerRepository _repo = TravelerRepository();
  List<Traveler> _travelers = const [];
  bool _loadingTravelers = true;
  bool _loadFailed = false;
  int _loadToken = 0;

  // Current profile index for the swipe-style discover
  int _currentProfileIndex = 0;
  final PageController _photoPageController = PageController();
  int _currentPhotoPage = 0;

  final List<String> _locationDatabase = [
    'Bali, Indonesia',
    'Barcelona, Spain',
    'Kyoto, Japan',
    'Santorini, Greece',
    'Marrakech, Morocco',
    'Banff, Canada',
    'Reykjavík, Iceland',
    'Phuket, Thailand',
    'Paris, France',
    'Rome, Italy',
    'New York, USA',
  ];

  @override
  void initState() {
    super.initState();
    _loadTravelers();
    _loadNotifications();
  }

  /// Loads the discover feed from the database. In "Going to..." mode only
  /// travellers heading to / living in the chosen place are returned.
  Future<void> _loadTravelers() async {
    final token = ++_loadToken;
    setState(() {
      _loadingTravelers = true;
      _loadFailed = false;
    });
    try {
      final list = await _repo.discover(
        destination: _isNearMe ? null : _selectedLocation?.split(',').first.trim(),
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _travelers = list;
        _currentProfileIndex = 0;
        _currentPhotoPage = 0;
      });
    } catch (_) {
      if (mounted && token == _loadToken) setState(() => _loadFailed = true);
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _loadingTravelers = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList('dismissed_notifications') ?? [];

      final broadcasts = await NotificationService().getNotifications(limit: 20);
      final matches = await _repo.matches();
      final likedMe = await _repo.likesReceived();

      final items = <Map<String, dynamic>>[
        for (final m in matches.take(10))
          {
            'id': 'match_${m.id}',
            'icon': Icons.favorite,
            'iconColor': AppColors.primary,
            'title': 'New Match!',
            'description': 'You and ${m.name} liked each other. Start chatting now!',
            'time': _ago(m.matchedAt),
            'sort': m.matchedAt,
          },
        for (final l in likedMe.take(10))
          {
            'id': 'like_${l.id}',
            'icon': Icons.favorite_border,
            'iconColor': AppColors.primary,
            'title': '${l.name} liked you',
            'description': 'Open Chats → New Matches to accept and start talking.',
            'time': _ago(l.likedAt),
            'sort': l.likedAt,
          },
        for (final b in broadcasts)
          {
            'id': 'bc_${b.id}',
            'icon': _iconFor(b.type),
            'iconColor': AppColors.accent,
            'title': b.title,
            'description': b.body,
            'time': _ago(b.sentAt),
            'sort': b.sentAt,
          },
      ]
        ..removeWhere((i) => dismissed.contains(i['id']))
        ..sort((a, b) => (b['sort'] as DateTime).compareTo(a['sort'] as DateTime));

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(items);
      });
    } catch (_) {
      // Offline: keep whatever we have.
    }
  }

  IconData _iconFor(NotificationType t) {
    switch (t) {
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.promo:
        return Icons.card_giftcard;
      case NotificationType.update:
        return Icons.system_update_alt;
      case NotificationType.announcement:
        return Icons.campaign_outlined;
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} mins ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays} days ago';
  }

  Future<void> _dismissNotificationPermanently(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('dismissed_notifications') ?? [];
    if (!dismissed.contains(id)) {
      dismissed.add(id);
      await prefs.setStringList('dismissed_notifications', dismissed);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _query = val;
      if (val.isEmpty) {
        _suggestions = [];
      } else {
        _suggestions = _locationDatabase
            .where((loc) => loc.toLowerCase().contains(val.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectSuggestion(String suggestion) {
    setState(() {
      _selectedLocation = suggestion;
      _searchController.text = suggestion;
      _query = suggestion;
      _suggestions = [];
      _searchFocusNode.unfocus();
    });
    _loadTravelers();
  }

  void _clearSearch() {
    final hadLocation = _selectedLocation != null;
    setState(() {
      _selectedLocation = null;
      _searchController.clear();
      _query = '';
      _suggestions = [];
    });
    if (hadLocation) _loadTravelers();
  }

  List<Traveler> get _filteredTravelers => _travelers;

  Traveler? get _currentTraveler {
    final list = _filteredTravelers;
    if (list.isEmpty || _currentProfileIndex >= list.length) return null;
    return list[_currentProfileIndex];
  }

  Future<void> _nextProfile(String action) async {
    final traveler = _currentTraveler;
    if (traveler == null) return;

    final kind = switch (action) {
      'like' => SwipeKind.like,
      'save' => SwipeKind.save,
      _ => SwipeKind.pass,
    };

    // Move on immediately; the write happens in the background.
    setState(() {
      _travelers = List.of(_travelers)..removeAt(_currentProfileIndex);
      if (_currentProfileIndex >= _travelers.length) _currentProfileIndex = 0;
      _currentPhotoPage = 0;
      if (_photoPageController.hasClients) _photoPageController.jumpToPage(0);
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final match = await _repo.swipe(traveler.id, kind);
      if (!mounted) return;
      final message = switch (kind) {
        SwipeKind.pass => 'Passed on ${traveler.name}',
        SwipeKind.save => 'Saved ${traveler.name} for later 🔖',
        SwipeKind.like => match
            ? "It's a match with ${traveler.name}! 🎉 Say hi in Chats."
            : 'You liked ${traveler.name}! 💕',
      };
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
      if (kind == SwipeKind.like) {
        // Show them as "Pending" (or as a new match) in Chats straight away.
        unawaited(context.read<ChatProvider>().onLiked());
      }
      if (match) _loadNotifications();
    } catch (_) {
      if (!mounted) return;
      // Put the card back so nothing is silently lost.
      setState(() => _travelers = [traveler, ..._travelers]);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save that. Check your connection.'),
      ));
    }
  }

  Future<void> _saveTrip() async {
    final place = _selectedLocation;
    if (place == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.saveTrip(
        destination: place,
        week: _selectedWeek,
        month: _selectedMonth,
        year: _selectedYear,
      );
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade600,
        content: Text(
          '✈️ Trip to $place for $_selectedTravelDate has been saved to your profile!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the trip. Check your connection.')),
      );
    }
  }

  void _openTravelerProfile(Traveler traveler) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelerProfileScreen(traveler: traveler),
      ),
    );
  }

  void _showDateSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Travel Date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Week Dropdown
                      Expanded(
                        child: _DatePickerDropdown(
                          label: 'Week',
                          value: _selectedWeek,
                          items: const [
                            '1st Week',
                            '2nd Week',
                            '3rd Week',
                            '4th Week'
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedWeek = val);
                              setDialogState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Month Dropdown
                      Expanded(
                        child: _DatePickerDropdown(
                          label: 'Month',
                          value: _selectedMonth,
                          items: const [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMonth = val);
                              setDialogState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Year Dropdown
                      Expanded(
                        child: _DatePickerDropdown(
                          label: 'Year',
                          value: _selectedYear,
                          items: const ['2026', '2027', '2028'],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedYear = val);
                              setDialogState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.primaryVibrantDark
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Confirm Date',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_notifications.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No new notifications',
                          style: TextStyle(color: context.rovlo.textSecondary),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          return Dismissible(
                            key: Key(item['id'] as String),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              final itemId = item['id'] as String;
                              setState(() {
                                _notifications.removeAt(index);
                              });
                              setSheetState(() {});
                              await _dismissNotificationPermanently(itemId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Notification permanently dismissed'),
                                    duration: Duration(milliseconds: 800),
                                  ),
                                );
                              }
                            },
                            child: _NotificationItem(
                              icon: item['icon'] as IconData,
                              iconColor: item['iconColor'] as Color,
                              title: item['title'] as String,
                              description: item['description'] as String,
                              time: item['time'] as String,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSecColor = context.rovlo.textSecondary;
    final cardColor = context.rovlo.card;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach =
        isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Column(
      children: [
        // ── App Bar Area ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: RovloLogo(
                  fontSize: 26,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => _showNotifications(context),
                    icon: Icon(
                      Icons.notifications_none_outlined,
                      color: isDark
                          ? AppColors.primaryVibrantDark
                          : AppColors.elementBlack,
                    ),
                  ),
                  if (_notifications.isNotEmpty)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryVibrantDark
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Tab Switcher ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Stack(
              children: [
                // Sliding Glass Bar
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment:
                      _isNearMe ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1.0,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.white54,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                // Tab Labels
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isNearMe = true;
                            _selectedLocation = null;
                            _searchController.clear();
                            _query = '';
                            _suggestions = [];
                          });
                          _loadTravelers();
                        },
                        child: Center(
                          child: Text(
                            'Feed',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  _isNearMe ? AppColors.accent : textSecColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isNearMe = false;
                          });
                          _loadTravelers();
                        },
                        child: Center(
                          child: Text(
                            'Going to...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  !_isNearMe ? AppColors.accent : textSecColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Search Bar & Date Dropdown Area (Only visible in 'Going to...' tab) ──
        if (!_isNearMe)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search destinations...',
                            prefixIcon: const Icon(Icons.search,
                                color: AppColors.accent),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date Selector (stretching to same height as search bar)
                      GestureDetector(
                        onTap: () => _showDateSelectionDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text(
                                _getFormattedDateCompact(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, idx) {
                        final item = _suggestions[idx];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          title: Text(item),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

        // Popular Active Destinations list (Only visible when Going to... and no place is searched yet)
        if (!_isNearMe && _selectedLocation == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Popular Active Destinations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _DestinationCard(
                        name: 'Bali',
                        image:
                            'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=400&q=80',
                        onTap: () => _selectSuggestion('Bali, Indonesia'),
                      ),
                      _DestinationCard(
                        name: 'Barcelona',
                        image:
                            'https://images.unsplash.com/photo-1539650116574-8efeb43e2750?auto=format&fit=crop&w=400&q=80',
                        onTap: () => _selectSuggestion('Barcelona, Spain'),
                      ),
                      _DestinationCard(
                        name: 'Kyoto',
                        image:
                            'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=400&q=80',
                        onTap: () => _selectSuggestion('Kyoto, Japan'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Save Trip option (Only visible when Going to... and a place has been selected/searched)
        if (!_isNearMe && _selectedLocation != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: InkWell(
              onTap: _saveTrip,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryPeach.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: primaryPeach.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_add, color: primaryPeach),
                    const SizedBox(width: 8),
                    Text(
                      'Save this Trip to My Profile',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.secondary
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),

        // ── Single Profile Card / Result List ───────────────────────────────────
        Expanded(
          child: _loadingTravelers
              ? Center(
                  child: RovloLoader(
                    size: 96,
                    messages: [
                      _isNearMe ? 'Finding travellers near you…' : 'Finding travellers going there…',
                      'Meeting your next travel buddy…',
                    ],
                  ),
                )
              : _loadFailed
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _loadTravelers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Could not load travellers. Tap to retry'),
                      ),
                    )
                  : _currentTraveler == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _isNearMe
                                  ? "You're all caught up! New travellers will show up here as they join."
                                  : 'No travellers heading to this place yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecColor),
                            ),
                          ),
                        )
                      : _ProfileCard(
                  key: ValueKey(_currentProfileIndex),
                  traveler: _currentTraveler!,
                  photoPageController: _photoPageController,
                  currentPhotoPage: _currentPhotoPage,
                  onPhotoPageChanged: (i) =>
                      setState(() => _currentPhotoPage = i),
                  onReject: () => _nextProfile('reject'),
                  onLike: () => _nextProfile('like'),
                  onSave: () => _nextProfile('save'),
                  onTapProfile: () => _openTravelerProfile(_currentTraveler!),
                ),
        ),
      ],
    );
  }
}

// ── Single Profile Card Widget ──────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final Traveler traveler;
  final PageController photoPageController;
  final int currentPhotoPage;
  final ValueChanged<int> onPhotoPageChanged;
  final VoidCallback onReject;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTapProfile;

  const _ProfileCard({
    super.key,
    required this.traveler,
    required this.photoPageController,
    required this.currentPhotoPage,
    required this.onPhotoPageChanged,
    required this.onReject,
    required this.onLike,
    required this.onSave,
    required this.onTapProfile,
  });

  List<String> get _images =>
      traveler.imageUrls.isNotEmpty ? traveler.imageUrls : [traveler.imageUrl];

  /// Tap left / right thirds of the photo to flip through pictures, tap the
  /// middle to open the full profile.
  void _onPhotoTap(double dx, double width) {
    final count = _images.length;
    if (count > 1 && dx < width * 0.3) {
      if (currentPhotoPage > 0) {
        photoPageController.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } else if (count > 1 && dx > width * 0.7) {
      if (currentPhotoPage < count - 1) {
        photoPageController.nextPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } else {
      onTapProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final about = traveler.about.isNotEmpty ? traveler.about : traveler.description;
    final locationText = traveler.dateRange.isNotEmpty
        ? '${traveler.location} · ${traveler.dateRange}'
        : traveler.location;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 84),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: cardColor,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.14),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Photo + overlays ─────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onPhotoTap(d.localPosition.dx, box.maxWidth),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: photoPageController,
                      itemCount: _images.length,
                      onPageChanged: onPhotoPageChanged,
                      itemBuilder: (context, index) => CachedNetworkImage(
                        imageUrl: _images[index],
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, __) => Container(
                          color: primary.withValues(alpha: 0.10),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.person, size: 64, color: Colors.white70),
                        ),
                      ),
                    ),

                    // Top scrim keeps the chips readable on bright photos.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom scrim for the text block.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 280,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.88),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Photo progress segments
                    if (_images.length > 1)
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: List.generate(_images.length, (i) {
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: currentPhotoPage == i
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                    // Top chips: verified (left) + where/when (right)
                    Positioned(
                      top: _images.length > 1 ? 28 : 18,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          if (traveler.isVerified)
                            _GlassChip(
                              icon: Icons.verified_rounded,
                              iconColor: const Color(0xFF7CC4FF),
                              label: 'Verified',
                            ),
                          const Spacer(),
                          if (locationText.isNotEmpty)
                            Flexible(
                              child: _GlassChip(
                                icon: Icons.flight_takeoff_rounded,
                                label: locationText,
                                maxWidth: 190,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Text block
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            traveler.nameWithAge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              shadows: const [
                                Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          if (traveler.distanceLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.near_me_rounded, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(
                                  traveler.distanceLabel,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (traveler.tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in traveler.tags.take(3))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                                    ),
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (about.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: about),
                                  TextSpan(
                                    text: '  Read more',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Action bar ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            color: cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _LabeledAction(
                  label: 'Pass',
                  child: _ActionButton(
                    icon: Icons.close_rounded,
                    color: Colors.red.shade400,
                    size: 42,
                    iconSize: 21,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onReject();
                    },
                  ),
                ),
                _LabeledAction(
                  label: 'Like',
                  emphasised: true,
                  child: _ActionButton(
                    icon: Icons.favorite_rounded,
                    color: primary,
                    size: 52,
                    iconSize: 25,
                    isPrimary: true,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onLike();
                    },
                  ),
                ),
                _LabeledAction(
                  label: 'Save',
                  child: _ActionButton(
                    icon: Icons.bookmark_rounded,
                    color: const Color(0xFF2196F3),
                    size: 42,
                    iconSize: 20,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSave();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack);
  }
}

/// Translucent pill used on top of photos.
class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    this.maxWidth,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledAction extends StatelessWidget {
  const _LabeledAction({
    required this.label,
    required this.child,
    this.emphasised = false,
  });

  final String label;
  final Widget child;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
            color: context.rovlo.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary
              ? color
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04)),
          shape: BoxShape.circle,
          border: isPrimary
              ? null
              : Border.all(
                  color: color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : color,
          size: iconSize,
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style:
                    TextStyle(color: context.rovlo.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                time,
                style: TextStyle(
                    color: context.rovlo.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final String name;
  final String image;
  final VoidCallback onTap;

  const _DestinationCard({
    required this.name,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(image),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DatePickerDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: context.rovlo.textSecondary,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
