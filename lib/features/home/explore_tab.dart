import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/rovlo_logo.dart';
import '../../models/traveler.dart';
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

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'icon': Icons.favorite,
      'iconColor': AppColors.primary,
      'title': 'New Match!',
      'description': 'Elena liked your profile back. Start chatting now!',
      'time': '2 mins ago',
    },
    {
      'id': '2',
      'icon': Icons.person_pin_circle,
      'iconColor': AppColors.accent,
      'title': 'Traveler nearby',
      'description': 'Julian is also in Bali and looking for backpackers.',
      'time': '1 hour ago',
    },
    {
      'id': '3',
      'icon': Icons.info_outline,
      'iconColor': Colors.blue,
      'title': 'Welcome to Rovlo',
      'description': 'Explore maps, find friends and enjoy your trip!',
      'time': 'Yesterday',
    },
  ];

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
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('dismissed_notifications') ?? [];
    setState(() {
      _notifications.removeWhere((item) => dismissed.contains(item['id']));
    });
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
  }

  void _clearSearch() {
    setState(() {
      _selectedLocation = null;
      _searchController.clear();
      _query = '';
      _suggestions = [];
    });
  }

  List<Traveler> get _filteredTravelers {
    if (_isNearMe) {
      return SampleTravelers.list;
    } else {
      if (_selectedLocation == null || _query.isEmpty) {
        return SampleTravelers.list;
      }
      final searchTerms = _query.toLowerCase().split(',');
      final primaryTerm = searchTerms.first.trim();
      return SampleTravelers.list.where((t) {
        return t.location.toLowerCase().contains(primaryTerm);
      }).toList();
    }
  }

  Traveler? get _currentTraveler {
    final list = _filteredTravelers;
    if (list.isEmpty || _currentProfileIndex >= list.length) return null;
    return list[_currentProfileIndex];
  }

  void _nextProfile(String action) {
    final traveler = _currentTraveler;
    if (traveler == null) return;

    String message;
    switch (action) {
      case 'reject':
        message = 'Passed on ${traveler.name}';
        break;
      case 'like':
        message = 'You liked ${traveler.name}! 💕';
        break;
      case 'save':
        message = 'Saved ${traveler.name} for later 🔖';
        break;
      default:
        message = '';
    }

    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    setState(() {
      if (_currentProfileIndex + 1 < _filteredTravelers.length) {
        _currentProfileIndex++;
      } else {
        _currentProfileIndex = 0; // Loop back
      }
      _currentPhotoPage = 0;
      if (_photoPageController.hasClients) {
        _photoPageController.jumpToPage(0);
      }
    });
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
                            _clearSearch();
                          });
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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade600,
                    content: Text(
                      '✈️ Trip to $_selectedLocation for $_selectedTravelDate has been saved to your profile!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
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
          child: _currentTraveler == null
              ? Center(
                  child: Text(
                    'No travelers found in this area.',
                    style: TextStyle(color: textSecColor),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach =
        isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 76),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Photo Section (Scrollable horizontally) ─────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTapProfile,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: photoPageController,
                    itemCount: _images.length,
                    onPageChanged: onPhotoPageChanged,
                    itemBuilder: (context, index) {
                      return Image.network(
                        _images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 50),
                        ),
                      );
                    },
                  ),
                  // Photo indicators at top
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: List.generate(_images.length, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
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
                  // Verified shield
                  if (traveler.isVerified)
                    Positioned(
                      top: 24,
                      left: 16,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryPeach.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  // Location + Date badge
                  Positioned(
                    top: 24,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${traveler.location} · ${traveler.dateRange}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom of image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
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
                  ),
                  // Name + Age + About 1.5 lines preview overlay
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${traveler.name}, ${traveler.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                            ),
                            if (traveler.isVerified) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                  size: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // About text overlay (1.5 lines with Read More)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                traveler.about.isNotEmpty
                                    ? traveler.about
                                    : traveler.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onTapProfile,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Read More',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action Buttons Row (Above Floating Navbar) ───────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject (X)
                _ActionButton(
                  icon: Icons.close_rounded,
                  color: Colors.red.shade400,
                  size: 48,
                  iconSize: 24,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onReject();
                  },
                ),
                // // Superlike (Star)
                // _ActionButton(
                //   icon: Icons.star_rounded,
                //   color: Colors.amber.shade600,
                //   size: 42,
                //   iconSize: 22,
                //   onTap: () {
                //     HapticFeedback.lightImpact();
                //     onSave();
                //   },
                // ),
                // Like (Heart)
                _ActionButton(
                  icon: Icons.favorite_rounded,
                  color: primaryPeach,
                  size: 58,
                  iconSize: 28,
                  isPrimary: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onLike();
                  },
                ),
                // Save (Bookmark)
                _ActionButton(
                  icon: Icons.bookmark_rounded,
                  color: const Color(0xFF2196F3),
                  size: 42,
                  iconSize: 20,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSave();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
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
              if (title.contains('Match') ||
                  title.contains('nearby') ||
                  title.contains('liked')) ...[
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Accepted match request! 💕')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Accept',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request declined.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child:
                          const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
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
