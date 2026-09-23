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
import '../../core/widgets/glass.dart';
import '../../core/widgets/keyboard_inset.dart';
import '../../core/widgets/rovlo_loader.dart';
import '../../models/hot_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/events_repository.dart';
import '../../services/location_service.dart';
import 'event_details_screen.dart';

/// Hotlist: real events for the user's city, from the database.
///
/// The city comes from the phone's location (or the one the user picked). The
/// events table is filled per city by the `sync-events` Edge Function, so
/// changing the city immediately shows what is cached and refreshes in the
/// background.
class HotTab extends StatefulWidget {
  const HotTab({super.key});

  @override
  State<HotTab> createState() => _HotTabState();
}

class _HotTabState extends State<HotTab> {
  static const String _prefsManualCity = 'rovlo_hot_city';

  // Remembered for the app session so switching tabs does not re-fetch.
  static final Map<String, DateTime> _syncedAt = {};
  static const Duration _resyncAfter = Duration(minutes: 30);

  static const List<String> _popularCities = [
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Hyderabad',
    'Kolkata',
    'Chennai',
    'Pune',
    'Goa',
    'Jaipur',
    'Ahmedabad',
    'Chandigarh',
    'Kochi',
    'London',
    'New York',
    'Dubai',
    'Singapore',
  ];

  static const List<String> _categories = [
    'All',
    'Hot Picks',
    'Nightlife',
    'Live Music',
    'Festivals',
    'Comedy',
    'Food & Drink',
    'Art & Culture',
    'Sports',
  ];

  final EventsRepository _repo = EventsRepository();

  String? _city; // city whose events are shown
  String? _detectedCity;
  bool _manualCity = false;
  LocationStatus? _locationProblem;
  double? _lat;
  double? _lng;

  List<HotEvent> _events = const [];
  bool _loading = true;
  bool _syncing = false;
  bool _failed = false;
  int _token = 0;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Location → city ─────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final manual = prefs.getString(_prefsManualCity);

    // 1. Show something right away: the city the user chose, or the last one
    //    we detected, or the one on their profile.
    final cachedFix = await LocationService.instance.cached();
    final startCity = manual ??
        cachedFix?.city ??
        auth.currentUser?.city ??
        _cityFromHomeBase(auth.currentUser?.homeBase);
    if (!mounted) return;
    _lat = cachedFix?.lat;
    _lng = cachedFix?.lng;
    if (startCity != null) {
      _manualCity = manual != null;
      _load(startCity);
    }

    // 2. Then find out where the phone really is.
    await _detectLocation(
        applyIfNotManual: manual == null, startedWith: startCity);
  }

  String? _cityFromHomeBase(String? homeBase) {
    if (homeBase == null || homeBase.trim().isEmpty) return null;
    return homeBase.split(',').first.trim();
  }

  Future<void> _detectLocation(
      {bool applyIfNotManual = true, String? startedWith}) async {
    final res = await LocationService.instance.locate();
    if (!mounted) return;

    if (!res.ok) {
      setState(() => _locationProblem = res.status);
      if (_city == null && startedWith == null) {
        // Nothing to show and no location: stop the spinner, ask the user.
        setState(() => _loading = false);
      }
      return;
    }

    final fix = res.fix!;
    _lat = fix.lat;
    _lng = fix.lng;
    setState(() {
      _locationProblem = null;
      _detectedCity = fix.city;
    });
    // Keep my profile position fresh (used by the map / nearby travellers).
    unawaited(context
        .read<AuthProvider>()
        .updateLocation(fix.lat, fix.lng, fix.city));

    if (applyIfNotManual &&
        fix.city != null &&
        !_manualCity &&
        fix.city != _city) {
      _load(fix.city!);
    }
  }

  Future<void> _useMyLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsManualCity);
    _manualCity = false;
    await _detectLocation();
    if (_detectedCity != null && mounted) _load(_detectedCity!);
  }

  Future<void> _chooseCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsManualCity, city);
    _manualCity = true;
    if (mounted) _load(city);
  }

  // ── Events ──────────────────────────────────────────────────────────────────

  Future<void> _load(String city, {bool force = false}) async {
    final token = ++_token;
    setState(() {
      _city = city;
      _loading = true;
      _failed = false;
      _selectedCategory = 'All';
    });

    try {
      final cached = await _repo.cached(city);
      if (!mounted || token != _token) return;
      setState(() {
        _events = cached;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }

    // Refresh from the providers (server-side cached per city).
    final key = EventsRepository.cityKey(city);
    final last = _syncedAt[key];
    final stale =
        last == null || DateTime.now().difference(last) > _resyncAfter;
    if (!force && !stale) return;

    setState(() => _syncing = true);
    final changed = await _repo.sync(city, lat: _lat, lng: _lng, force: force);
    _syncedAt[key] = DateTime.now();
    if (!mounted || token != _token) return;
    if (changed) {
      try {
        final fresh = await _repo.cached(city);
        if (!mounted || token != _token) return;
        setState(() => _events = fresh);
      } catch (_) {}
    }
    if (mounted && token == _token) setState(() => _syncing = false);
  }

  List<HotEvent> get _filteredEvents {
    final q = _searchQuery.trim().toLowerCase();
    return _events.where((evt) {
      final matchesCategory = _selectedCategory == 'All' ||
          (_selectedCategory == 'Hot Picks'
              ? (evt.isFeatured || (evt.rating ?? 0) >= 4.5)
              : evt.category.toLowerCase() == _selectedCategory.toLowerCase());
      final matchesQuery = q.isEmpty ||
          evt.title.toLowerCase().contains(q) ||
          evt.venue.toLowerCase().contains(q) ||
          evt.category.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  // ── City picker ─────────────────────────────────────────────────────────────

  Future<void> _openCityPicker() async {
    final extra = await _repo.citiesWithEvents();
    if (!mounted) return;
    final suggestions = <String>[
      ...extra,
      ..._popularCities.where((c) => !extra.contains(c)),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CityPickerSheet(
        detectedCity: _detectedCity,
        locationProblem: _locationProblem,
        suggestions: suggestions,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _CityPickerSheet.useLocation) {
      await _useMyLocation();
    } else {
      await _chooseCity(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue =
        isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final events = _filteredEvents;
    final cityLabel = _city ?? 'Choose city';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Column(
        children: [
          // ── FIXED: title, location, search bar, category pills ──────────────
          // Everything up to and including the filters stays put; only the
          // event cards below scroll.
          // ── Title + location chip ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hotlist',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _syncing
                            ? 'Refreshing events…'
                            : 'Trending events & experiences',
                        style: TextStyle(
                          color: context.rovlo.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openCityPicker,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 170),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _manualCity ? Icons.location_city : Icons.my_location,
                          size: 14,
                          color: primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            cityLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Location permission hint ─────────────────────────────────────
          if (_locationProblem != null && !_manualCity)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _LocationHint(
                status: _locationProblem!,
                onFix: () async {
                  if (_locationProblem == LocationStatus.denied ||
                      _locationProblem == LocationStatus.unavailable) {
                    await _detectLocation();
                  } else {
                    await LocationService.instance
                        .openSettings(_locationProblem!);
                  }
                },
                onPick: _openCityPicker,
              ),
            ),

          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13.5),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search artists, venues, festivals...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: context.rovlo.textSecondary
                              .withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        filled: false,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          // ── Category pills ───────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryBlue
                          : (isDark ? AppColors.darkCard : AppColors.lightCard),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? primaryBlue
                            : (isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── SCROLLING: spotlight + event cards ──────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_city != null) await _load(_city!, force: true);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // ── Spotlight ────────────────────────────────────────────────────
                  if (!_loading &&
                      events.isNotEmpty &&
                      _searchQuery.isEmpty &&
                      _selectedCategory == 'All')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: _FeaturedSpotlightCard(
                          event: events.first,
                          onTap: () => _openEventDetails(events.first),
                        ),
                      ),
                    ),

                  // ── Section title ────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Events (${events.length})',
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          if (_city != null)
                            Flexible(
                              child: Text(
                                'Location: $_city',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── List / states ────────────────────────────────────────────────
                  if (_loading || (_syncing && _events.isEmpty))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 56),
                        child: Center(
                          child: RovloLoader(
                            messages: [
                              if (_city != null)
                                'Finding events in $_city…'
                              else
                                'Finding events near you…',
                              'Checking what is on this week…',
                              'Picking the hottest spots…',
                              'Almost there…',
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_city == null)
                    SliverToBoxAdapter(
                      child: _EmptyState(
                        icon: Icons.location_searching,
                        message:
                            'Choose your city to see what is happening around you.',
                        actionLabel: 'Choose city',
                        onAction: _openCityPicker,
                      ),
                    )
                  else if (_failed)
                    SliverToBoxAdapter(
                      child: _EmptyState(
                        icon: Icons.cloud_off,
                        message:
                            'Could not load events. Check your connection.',
                        actionLabel: 'Try again',
                        onAction: () => _load(_city!),
                      ),
                    )
                  else if (events.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyState(
                        icon: Icons.event_busy,
                        message: _syncing
                            ? 'Looking for events in $_city…'
                            : 'No events found in $_city${_selectedCategory == 'All' ? '' : ' for "$_selectedCategory"'} yet.',
                        actionLabel: 'Change city',
                        onAction: _openCityPicker,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final event = events[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _HotEventCard(
                                event: event,
                                onTap: () => _openEventDetails(event),
                              )
                                  .animate(delay: (40 * (index % 8)).ms)
                                  .fadeIn()
                                  .slideY(begin: 0.06),
                            );
                          },
                          childCount: events.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEventDetails(HotEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(event: event),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// City picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.detectedCity,
    required this.locationProblem,
    required this.suggestions,
  });

  static const String useLocation = '__use_location__';

  final String? detectedCity;
  final LocationStatus? locationProblem;
  final List<String> suggestions;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final matches = widget.suggestions
        .where((c) => _q.isEmpty || c.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final typed = _q.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Choose location',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _q = v),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
                },
                decoration: const InputDecoration(
                  hintText: 'Search any city…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ListTile(
                    leading: Icon(Icons.my_location, color: primary),
                    title: const Text('Use my current location'),
                    subtitle: Text(
                      widget.detectedCity != null
                          ? 'Detected: ${widget.detectedCity}'
                          : (widget.locationProblem != null
                              ? 'Location is off or not allowed'
                              : 'Detect automatically'),
                    ),
                    onTap: () =>
                        Navigator.pop(context, _CityPickerSheet.useLocation),
                  ),
                  if (typed.length >= 2 &&
                      !matches
                          .any((c) => c.toLowerCase() == typed.toLowerCase()))
                    ListTile(
                      leading: Icon(Icons.travel_explore, color: primary),
                      title: Text('Search events in "$typed"'),
                      onTap: () => Navigator.pop(context, typed),
                    ),
                  for (final c in matches)
                    ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(c),
                      onTap: () => Navigator.pop(context, c),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationHint extends StatelessWidget {
  const _LocationHint({
    required this.status,
    required this.onFix,
    required this.onPick,
  });

  final LocationStatus status;
  final VoidCallback onFix;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      LocationStatus.serviceOff => 'Turn on location to see events near you.',
      LocationStatus.deniedForever =>
        'Location permission is blocked. Enable it in settings, or pick a city.',
      _ => 'Allow location to see events near you, or pick a city.',
    };
    final action = status == LocationStatus.serviceOff ||
            status == LocationStatus.deniedForever
        ? 'Open settings'
        : 'Allow';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onFix, child: Text(action)),
          TextButton(onPressed: onPick, child: const Text('Pick city')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.rovlo.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Event photo with a themed gradient fallback (no photo / failed to load).
class _EventImage extends StatelessWidget {
  const _EventImage({required this.event, this.height});

  final HotEvent event;
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                event.themeColor.withValues(alpha: 0.85),
                event.themeColor.withValues(alpha: 0.35),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.celebration_outlined,
              size: 44, color: Colors.white70),
        );

    if (event.imageUrl.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: event.imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) =>
          Container(color: event.themeColor.withValues(alpha: 0.15)),
      errorWidget: (_, __, ___) => fallback(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured Spotlight Card with Theme Glow
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedSpotlightCard extends StatelessWidget {
  const _FeaturedSpotlightCard({
    required this.event,
    required this.onTap,
  });

  final HotEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: event.themeColor.withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _EventImage(event: event),
              // Glow Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black26,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: GlassBadge(
                  label: 'FEATURED SPOTLIGHT',
                ),
              ),
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time.isEmpty
                          ? event.date
                          : '${event.date} • ${event.time}',
                      style: TextStyle(
                        color: event.themeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          event.price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hot Event Card Block
// ─────────────────────────────────────────────────────────────────────────────

class _HotEventCard extends StatelessWidget {
  const _HotEventCard({
    required this.event,
    required this.onTap,
  });

  final HotEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: event.themeColor.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Thumbnail Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: _EventImage(event: event, height: 160),
                  ),
                  // Dark Vignette
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black26,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Category label (glass, event accent as a dot)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GlassBadge(
                      label: event.category,
                      fontSize: 10.5,
                      horizontalPadding: 10,
                      verticalPadding: 5,
                    ),
                  ),
                  // Attending count (only when the source tells us)
                  if (event.attending.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: GlassBadge(
                        label: event.attending,
                        fontSize: 11,
                        horizontalPadding: 10,
                        verticalPadding: 5,
                      ),
                    ),
                ],
              ),
            ),

            // Event Content Block
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 13, color: event.themeColor),
                      const SizedBox(width: 6),
                      Text(
                        event.time.isEmpty
                            ? event.date
                            : '${event.date} • ${event.time}',
                        style: TextStyle(
                          color: event.themeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    event.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Venue & Address
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: TextStyle(
                            color: context.rovlo.textSecondary,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Divider & Bottom Price / CTA
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.price == 'See tickets'
                                  ? 'Tickets'
                                  : 'Starting from',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.rovlo.textSecondary,
                              ),
                            ),
                            Text(
                              event.price,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: event.themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: event.themeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: event.themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios,
                                  size: 11, color: event.themeColor),
                            ],
                          ),
                        ),
                      ],
                    ),
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
