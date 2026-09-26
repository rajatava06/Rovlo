import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/rovlo_loader.dart';
import '../../core/widgets/rovlo_logo.dart';
import '../../models/admin_notification.dart';
import '../../models/traveler.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/traveler_repository.dart';
import 'traveler_profile_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  static const _weeks = ['1st Week', '2nd Week', '3rd Week', '4th Week'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _popular = <PlaceResult>[
    PlaceResult(
      name: 'Bali, Indonesia',
      title: 'Bali',
      subtitle: 'Indonesia',
      lat: -8.4095,
      lng: 115.1889,
    ),
    PlaceResult(
      name: 'Barcelona, Spain',
      title: 'Barcelona',
      subtitle: 'Spain',
      lat: 41.3874,
      lng: 2.1686,
    ),
    PlaceResult(
      name: 'Kyoto, Japan',
      title: 'Kyoto',
      subtitle: 'Japan',
      lat: 35.0116,
      lng: 135.7681,
    ),
  ];

  bool _isNearMe = true;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // "Going to…" search + date
  Timer? _searchDebounce;
  int _searchToken = 0;
  bool _searching = false;
  bool _searchDone = false;
  List<PlaceResult> _placeResults = [];
  String? _destLabel;
  double? _destLat;
  double? _destLng;
  late String _selectedWeek;
  late String _selectedMonth;
  late String _selectedYear;

  List<Trip> _myTrips = const [];
  List<Traveler> _going = const [];
  bool _loadingGoing = false;
  bool _goingFailed = false;
  int _goingToken = 0;
  bool _savingTrip = false;

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

  /// Last day of the chosen travel week (4th week runs to the end of the month).
  DateTime get _selectedWindowEnd {
    final month = _months.indexOf(_selectedMonth) + 1;
    final year = int.tryParse(_selectedYear) ?? DateTime.now().year;
    final n = _weeks.indexOf(_selectedWeek) + 1;
    return n >= 4 ? DateTime(year, month + 1, 0) : DateTime(year, month, 7 * n);
  }

  bool get _selectedDatesInPast {
    final now = DateTime.now();
    return _selectedWindowEnd.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Same place = within 75 km (same rule as the database), or the same name
  /// for old trips saved without coordinates.
  bool _sameDestination(Trip t) {
    final lat = _destLat, lng = _destLng, label = _destLabel;
    if (label == null) return false;
    if (t.lat != null && t.lng != null && lat != null && lng != null) {
      return const Distance().as(
              LengthUnit.Kilometer, LatLng(t.lat!, t.lng!), LatLng(lat, lng)) <=
          75;
    }
    return t.destination.split(',').first.trim().toLowerCase() ==
        label.split(',').first.trim().toLowerCase();
  }

  bool get _tripAlreadySaved => _myTrips.any((t) =>
      t.week == _selectedWeek &&
      t.month == _selectedMonth &&
      t.year == _selectedYear &&
      _sameDestination(t));

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeek = _weeks[((now.day - 1) ~/ 7).clamp(0, 3)];
    _selectedMonth = _months[now.month - 1];
    _selectedYear = '${now.year}';
    TravelerRepository.tripsRevision.addListener(_loadMyTrips);
    _loadTravelers();
    _loadNotifications();
    _loadMyTrips();
  }

  /// Loads the discover feed from the database (closest first).
  Future<void> _loadTravelers() async {
    final token = ++_loadToken;
    setState(() {
      _loadingTravelers = true;
      _loadFailed = false;
    });
    try {
      final list = await _repo.discover();
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
    TravelerRepository.tripsRevision.removeListener(_loadMyTrips);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  // ── "Going to…" search ─────────────────────────────────────────────────────

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final token = ++_searchToken;
    final q = val.trim();
    setState(() {
      _query = val;
      _searchDone = false;
      _searching = q.length >= 2;
      if (q.length < 2) _placeResults = [];
    });
    if (q.length < 2) return;
    // Debounced: one request after the user pauses typing (the free geocoder
    // asks apps not to fire a request per keystroke).
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await LocationService.instance.searchDestinations(q);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _placeResults = results;
        _searching = false;
        _searchDone = true;
      });
    });
  }

  void _selectPlace(PlaceResult place) {
    _searchDebounce?.cancel();
    _searchToken++;
    setState(() {
      _destLabel = place.label;
      _destLat = place.lat;
      _destLng = place.lng;
      _searchController.text = place.label;
      _query = place.label;
      _placeResults = [];
      _searching = false;
      _searchDone = false;
      _searchFocusNode.unfocus();
    });
    _loadGoing();
  }

  /// Tapping one of my saved trips searches that place + those dates.
  void _selectMyTrip(Trip trip) {
    _searchDebounce?.cancel();
    _searchToken++;
    setState(() {
      _destLabel = trip.destination;
      _destLat = trip.lat;
      _destLng = trip.lng;
      _selectedWeek = trip.week;
      _selectedMonth = trip.month;
      _selectedYear = trip.year;
      _searchController.text = trip.destination;
      _query = trip.destination;
      _placeResults = [];
      _searching = false;
      _searchDone = false;
      _searchFocusNode.unfocus();
    });
    _loadGoing();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchToken++;
    _goingToken++;
    setState(() {
      _destLabel = null;
      _destLat = null;
      _destLng = null;
      _searchController.clear();
      _query = '';
      _placeResults = [];
      _searching = false;
      _searchDone = false;
      _going = const [];
      _loadingGoing = false;
      _goingFailed = false;
    });
  }

  Future<void> _loadMyTrips() async {
    try {
      final trips = await _repo.myTrips();
      if (mounted) setState(() => _myTrips = trips);
    } catch (_) {
      // Offline: keep what we have.
    }
  }

  /// Everyone else going to the chosen place, best date match first.
  Future<void> _loadGoing() async {
    final label = _destLabel;
    if (label == null) return;
    if (_selectedDatesInPast) {
      _goingToken++;
      setState(() {
        _going = const [];
        _loadingGoing = false;
        _goingFailed = false;
      });
      return;
    }
    final token = ++_goingToken;
    setState(() {
      _loadingGoing = true;
      _goingFailed = false;
    });
    try {
      final list = await _repo.goingTo(
        destination: label,
        lat: _destLat,
        lng: _destLng,
        week: _selectedWeek,
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (!mounted || token != _goingToken) return;
      setState(() => _going = list);
    } catch (_) {
      if (mounted && token == _goingToken) setState(() => _goingFailed = true);
    } finally {
      if (mounted && token == _goingToken) {
        setState(() => _loadingGoing = false);
      }
    }
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
    await _swipeTraveler(traveler, kind);
  }

  /// Like / pass / save from the swipe card or from the "Going to…" list. The
  /// person disappears from both lists straight away; the write happens in the
  /// background and is rolled back if it fails.
  Future<void> _swipeTraveler(Traveler traveler, SwipeKind kind) async {
    final feedIdx = _travelers.indexWhere((t) => t.id == traveler.id);
    final goingIdx = _going.indexWhere((t) => t.id == traveler.id);

    setState(() {
      if (feedIdx >= 0) {
        _travelers = List.of(_travelers)..removeAt(feedIdx);
        if (_currentProfileIndex >= _travelers.length) _currentProfileIndex = 0;
        _currentPhotoPage = 0;
        if (_photoPageController.hasClients) _photoPageController.jumpToPage(0);
      }
      if (goingIdx >= 0) _going = List.of(_going)..removeAt(goingIdx);
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
      setState(() {
        if (feedIdx >= 0) {
          _travelers = List.of(_travelers)
            ..insert(feedIdx.clamp(0, _travelers.length), traveler);
        }
        if (goingIdx >= 0) {
          _going = List.of(_going)
            ..insert(goingIdx.clamp(0, _going.length), traveler);
        }
      });
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save that. Check your connection.'),
      ));
    }
  }

  Future<void> _saveTrip() async {
    final place = _destLabel;
    if (place == null || _savingTrip) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedDatesInPast) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick dates that are still ahead of you.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _savingTrip = true);
    try {
      await _repo.saveTrip(
        destination: place,
        lat: _destLat,
        lng: _destLng,
        week: _selectedWeek,
        month: _selectedMonth,
        year: _selectedYear,
      );
      // The profile shows my next trip, so pull the fresh copy.
      unawaited(auth.refreshCurrentUser());
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
    } finally {
      if (mounted) setState(() => _savingTrip = false);
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
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
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
                          items: _weeks,
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
                          items: _months,
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
                          items: [
                            for (var y = DateTime.now().year;
                                y <= DateTime.now().year + 2;
                                y++)
                              '$y',
                          ],
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
    ).whenComplete(() {
      if (!mounted || _destLabel == null) return;
      if (_selectedDatesInPast) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pick dates that are still ahead of you.')),
        );
      }
      _loadGoing();
    });
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
                          setState(() => _isNearMe = true);
                          if (_travelers.isEmpty || _loadFailed) _loadTravelers();
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
                          setState(() => _isNearMe = false);
                          _loadMyTrips();
                          if (_destLabel != null) _loadGoing();
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

        // Feed = swipe cards. Going to… = scrollable list (search, my trips, everyone
        // else going to the same place / dates).
        Expanded(
          child: _isNearMe
              ? _buildFeed(textSecColor)
              : _buildGoingTo(isDark, cardColor, primaryPeach, textSecColor),
        ),
      ],
    );
  }

  // ── Feed (single swipe card) ────────────────────────────────────────────────

  Widget _buildFeed(Color textSecColor) {
    if (_loadingTravelers) {
      return const Center(
        child: RovloLoader(
          size: 96,
          messages: [
            'Finding travellers near you…',
            'Meeting your next travel buddy…',
          ],
        ),
      );
    }
    if (_loadFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadTravelers,
          icon: const Icon(Icons.refresh),
          label: const Text('Could not load travellers. Tap to retry'),
        ),
      );
    }
    final traveler = _currentTraveler;
    if (traveler == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            "You're all caught up! New travellers will show up here as they join.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecColor),
          ),
        ),
      );
    }
    return _ProfileCard(
      key: ValueKey(_currentProfileIndex),
      traveler: traveler,
      photoPageController: _photoPageController,
      currentPhotoPage: _currentPhotoPage,
      onPhotoPageChanged: (i) => setState(() => _currentPhotoPage = i),
      onReject: () => _nextProfile('reject'),
      onLike: () => _nextProfile('like'),
      onSave: () => _nextProfile('save'),
      onTapProfile: () => _openTravelerProfile(traveler),
    );
  }

  // ── Going to… ───────────────────────────────────────────────────────────────

  static const _popularImages = [
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1539650116574-8efeb43e2750?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=400&q=80',
  ];

  Widget _buildGoingTo(
    bool isDark,
    Color cardColor,
    Color primaryPeach,
    Color textSecColor,
  ) {
    final hasDest = _destLabel != null;
    final destShort = _destLabel?.split(',').first.trim() ?? '';
    final typed = _query.trim().length >= 2;
    final showNoPlaces = typed && _searchDone && _placeResults.isEmpty && !hasDest;
    final headerStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white70 : Colors.black54,
    );

    final children = <Widget>[
      // Search + date
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search any city, island or country…',
                  prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Date selector (same height as the search bar)
            GestureDetector(
              onTap: () => _showDateSelectionDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.grey.shade100,
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

      // Place suggestions (from the free geocoder)
      if (_placeResults.isNotEmpty)
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
          child: Column(
            children: [
              for (final place in _placeResults)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                  title: Text(place.title ?? place.name),
                  subtitle: (place.subtitle ?? '').isEmpty
                      ? null
                      : Text(place.subtitle!),
                  onTap: () => _selectPlace(place),
                ),
            ],
          ),
        ),
      if (showNoPlaces)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'No places found for “${_query.trim()}”. Try another spelling.',
            style: TextStyle(color: textSecColor),
          ),
        ),

      // My saved trips (also shown on my profile)
      if (_myTrips.isNotEmpty && _placeResults.isEmpty) ...[
        const SizedBox(height: 16),
        Text('Your trips', style: headerStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final trip in _myTrips)
              _TripChip(
                trip: trip,
                selected: hasDest &&
                    _sameDestination(trip) &&
                    trip.week == _selectedWeek &&
                    trip.month == _selectedMonth &&
                    trip.year == _selectedYear,
                onTap: () => _selectMyTrip(trip),
              ),
          ],
        ),
      ],

      // Nothing searched yet → popular places
      if (!hasDest && _placeResults.isEmpty && !showNoPlaces) ...[
        const SizedBox(height: 20),
        Text('Popular Active Destinations', style: headerStyle),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _popular.length; i++)
                _DestinationCard(
                  name: _popular[i].title ?? _popular[i].name,
                  image: _popularImages[i],
                  onTap: () => _selectPlace(_popular[i]),
                ),
            ],
          ),
        ),
      ],

      // A place is chosen → save it + everyone else going there
      if (hasDest && _placeResults.isEmpty) ...[
        const SizedBox(height: 14),
        _buildTripCard(isDark, primaryPeach),
        const SizedBox(height: 20),
        if (_selectedDatesInPast)
          Text(
            'That week has already passed. Pick dates that are still ahead of you.',
            style: TextStyle(color: textSecColor),
          )
        else if (_loadingGoing)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: RovloLoader(
                size: 72,
                messages: [
                  'Finding travellers going there…',
                  'Meeting your next travel buddy…',
                ],
              ),
            ),
          )
        else if (_goingFailed)
          Center(
            child: TextButton.icon(
              onPressed: _loadGoing,
              icon: const Icon(Icons.refresh),
              label: const Text('Could not load travellers. Tap to retry'),
            ),
          )
        else if (_going.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nobody else is going to $destShort yet. Save your trip and you\'ll '
              'show up for everyone heading there.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecColor),
            ),
          )
        else ...[
          Text(
            '${_going.length} ${_going.length == 1 ? 'traveller' : 'travellers'} going to $destShort',
            style: headerStyle,
          ),
          for (var i = 0; i < _going.length; i++) ...[
            if (i == 0 || _going[i].dateMatch != _going[i - 1].dateMatch)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Text(
                  switch (_going[i].dateMatch) {
                    'same' => 'Same dates · $_selectedTravelDate',
                    'near' => 'Around your dates (within a month)',
                    _ => 'Later trips to $destShort',
                  },
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: primaryPeach,
                  ),
                ),
              ),
            _GoingCard(
              key: ValueKey(_going[i].id),
              traveler: _going[i],
              onTap: () => _openTravelerProfile(_going[i]),
              onPass: () => _swipeTraveler(_going[i], SwipeKind.pass),
              onSave: () => _swipeTraveler(_going[i], SwipeKind.save),
              onLike: () => _swipeTraveler(_going[i], SwipeKind.like),
            ),
          ],
        ],
      ],
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadMyTrips(),
          if (hasDest) _loadGoing(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: children,
      ),
    );
  }

  /// "Bali, Indonesia · 2nd Week, Oct 2026" + Save button (or the saved state).
  Widget _buildTripCard(bool isDark, Color primaryPeach) {
    final saved = _tripAlreadySaved;
    final destShort = _destLabel?.split(',').first.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryPeach.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryPeach.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: primaryPeach, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _destLabel ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              _selectedTravelDate,
              style: TextStyle(
                fontSize: 13,
                color: context.rovlo.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (saved)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade500, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On your profile — travellers going to $destShort can find you.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (_savingTrip || _selectedDatesInPast) ? null : _saveTrip,
                icon: _savingTrip
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bookmark_add, color: Colors.white, size: 18),
                label: const Text(
                  'Save this Trip to My Profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPeach,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── "Going to…" list widgets ────────────────────────────────────────────────

class _TripChip extends StatelessWidget {
  const _TripChip({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final Trip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.18)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff_rounded, size: 14, color: primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${trip.destination.split(',').first.trim()} · ${trip.month} ${trip.week.replaceAll(' Week', 'W')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One traveller in the "Going to…" list.
class _GoingCard extends StatelessWidget {
  const _GoingCard({
    super.key,
    required this.traveler,
    required this.onTap,
    required this.onPass,
    required this.onSave,
    required this.onLike,
  });

  final Traveler traveler;
  final VoidCallback onTap;
  final VoidCallback onPass;
  final VoidCallback onSave;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textSec = context.rovlo.textSecondary;
    final about = traveler.about.isNotEmpty ? traveler.about : traveler.description;

    final (badgeText, badgeColor) = switch (traveler.dateMatch) {
      'same' => ('Same dates', Colors.green.shade500),
      'near' => ('Near your dates', Colors.orange.shade600),
      _ => ('Later trip', Colors.blueGrey.shade400),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 118,
                child: CachedNetworkImage(
                  imageUrl: traveler.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: primary.withValues(alpha: 0.10)),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.person, size: 40, color: Colors.white70),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          traveler.nameWithAge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (traveler.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded, size: 16, color: primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (traveler.dateRange.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.event_rounded, size: 13, color: textSec),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            traveler.dateRange,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: textSec),
                          ),
                        ),
                      ],
                    ),
                  if (traveler.distanceLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.near_me_rounded, size: 13, color: textSec),
                        const SizedBox(width: 4),
                        Text(
                          traveler.distanceLabel,
                          style: TextStyle(fontSize: 12.5, color: textSec),
                        ),
                      ],
                    ),
                  ],
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.3, color: textSec),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionButton(
                        icon: Icons.close_rounded,
                        color: Colors.red.shade400,
                        size: 36,
                        iconSize: 18,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onPass();
                        },
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        icon: Icons.bookmark_rounded,
                        color: const Color(0xFF2196F3),
                        size: 36,
                        iconSize: 17,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onSave();
                        },
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        icon: Icons.favorite_rounded,
                        color: primary,
                        size: 42,
                        iconSize: 20,
                        isPrimary: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onLike();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                        top: 10,
                        left: 8,
                        right: 8,
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
                      top: _images.length > 1 ? 24 : 10,
                      left: 8,
                      right: 8,
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
