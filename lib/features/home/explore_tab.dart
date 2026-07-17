import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';

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

  final List<String> _locationDatabase = [
    'Bali, Indonesia',
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
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      // Near Me shows all Bali travelers (matching our mock location)
      return SampleTravelers.list;
    } else {
      if (_selectedLocation == null || _query.isEmpty) {
        return SampleTravelers.list;
      }
      // Filter by query (e.g. "Bali")
      final searchTerms = _query.toLowerCase().split(',');
      final primaryTerm = searchTerms.first.trim();
      return SampleTravelers.list.where((t) {
        return t.location.toLowerCase().contains(primaryTerm);
      }).toList();
    }
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
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
              _NotificationItem(
                icon: Icons.favorite,
                iconColor: AppColors.primary,
                title: 'New Match!',
                description: 'Elena liked your profile back. Start chatting now!',
                time: '2 mins ago',
              ),
              const Divider(height: 24),
              _NotificationItem(
                icon: Icons.person_pin_circle,
                iconColor: AppColors.accent,
                title: 'Traveler nearby',
                description: 'Julian is also in Bali and looking for backpackers.',
                time: '1 hour ago',
              ),
              const Divider(height: 24),
              _NotificationItem(
                icon: Icons.info_outline,
                iconColor: Colors.blue,
                title: 'Welcome to Rovlo',
                description: 'Explore maps, find friends and enjoy your trip!',
                time: 'Yesterday',
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSecColor = context.rovlo.textSecondary;
    final cardColor = context.rovlo.card;

    return Column(
      children: [
        // ── App Bar Area ───────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Rovlo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.primaryVibrantDark
                          : AppColors.elementBlack, // bold black element
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _showNotifications(context),
                      icon: Icon(
                        Icons.notifications_none_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.primaryVibrantDark
                            : AppColors.elementBlack, // black element in light mode
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
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
        ),

        // ── Tab Switcher ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNearMe = true;
                        _clearSearch();
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isNearMe
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface
                                : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: _isNearMe
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Near Me',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isNearMe
                              ? AppColors.accent
                              : textSecColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNearMe = false;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_isNearMe
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface
                                : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: !_isNearMe
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Going to...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: !_isNearMe
                              ? AppColors.accent
                              : textSecColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Search Bar Area (Only visible in 'Going to...' tab) ────────────────
        if (!_isNearMe)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search destinations...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
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
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          title: Text(item),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

        // ── Traveler Card List ──────────────────────────────────────────────────
        Expanded(
          child: _filteredTravelers.isEmpty
              ? Center(
                  child: Text(
                    'No travelers going to this location yet.',
                    style: TextStyle(color: textSecColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _filteredTravelers.length,
                  itemBuilder: (context, idx) {
                    final traveler = _filteredTravelers[idx];
                    return _TravelerCard(traveler: traveler);
                  },
                ),
        ),
      ],
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: context.rovlo.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(color: context.rovlo.textSecondary.withValues(alpha: 0.6), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TravelerCard extends StatelessWidget {
  final Traveler traveler;

  const _TravelerCard({required this.traveler});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Full-bleed Image Container
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 0.85,
                child: Image.network(
                  traveler.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, size: 50),
                  ),
                ),
              ),
              // Shield icon overlay top left
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              // Location + Date badge overlay top right
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'In ${traveler.location}: ${traveler.dateRange}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Name + age overlay bottom left
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
                    const SizedBox(height: 8),
                    // Tags row
                    Row(
                      children: [
                        // Tag 1: Dark outline style
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            traveler.tags[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tag 2: Peach filled style
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            traveler.tags[1],
                            style: const TextStyle(
                              color: AppColors.lightTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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

          // Bottom Button Bar Area (Message + Fav)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline_outlined, color: Colors.white),
                      label: const Text(
                        'Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5A2B), // Warm brown color matching screenshot
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
