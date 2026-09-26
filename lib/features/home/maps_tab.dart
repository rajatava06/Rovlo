import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/online_dot.dart';
import '../../models/traveler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/app_navigation.dart';
import '../../services/chat_repository.dart';
import '../../services/location_service.dart';
import '../../services/location_sharing_service.dart';
import '../../services/traveler_repository.dart';
import 'chat_room_screen.dart';
import 'traveler_profile_screen.dart';

enum _MapStyle { standard, satellite, terrain }

/// Real, interactive map (OpenStreetMap data — no API key needed).
///
/// * Shows the device position and every nearby traveller who is sharing their
///   location, as their profile picture (people using Ghost Mode never appear;
///   coordinates are blurred ~100 m). A green dot means they are online now, and
///   the pins refresh every few seconds.
/// * Tap a pin → send a **chat request**. Once they accept, you can chat.
/// * Tiles: MapTiler when `MAPTILER_KEY` is provided, otherwise OpenStreetMap
///   (standard), OpenTopoMap (terrain) and Esri World Imagery (satellite).
class MapsTab extends StatefulWidget {
  const MapsTab({super.key});

  @override
  State<MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends State<MapsTab> {
  static const LatLng _fallbackCenter = LatLng(20.5937, 78.9629); // India

  final MapController _map = MapController();
  final TravelerRepository _repo = TravelerRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _mapReady = false;
  _MapStyle _style = _MapStyle.standard;

  LatLng? _me;
  LocationStatus? _locationProblem;
  bool _locating = false;

  List<Traveler> _travelers = const [];
  Traveler? _selected;
  bool _loadingTravelers = false;
  bool _actionBusy = false;
  LatLng? _searchCenter;
  Timer? _refreshTimer;

  /// A location shared in a chat, shown as a red pin until it is closed.
  MapFocusTarget? _focus;

  /// Pins reload on their own this often while the map is open.
  static const Duration _refreshEvery = Duration(seconds: 20);

  bool _showSearchArea = false;
  List<PlaceResult> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _focus = AppNavigation.mapFocus.value;
    AppNavigation.mapFocus.addListener(_onFocusChanged);
    _init();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) {
      final center = _searchCenter;
      if (mounted && center != null && !_loadingTravelers) {
        _loadTravelers(center, silent: true);
      }
    });
  }

  @override
  void dispose() {
    AppNavigation.mapFocus.removeListener(_onFocusChanged);
    // The pin is for this visit only.
    AppNavigation.mapFocus.value = null;
    _refreshTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final target = AppNavigation.mapFocus.value;
    if (!mounted) return;
    setState(() {
      _focus = target;
      if (target != null) _selected = null;
    });
    if (target != null) _moveTo(LatLng(target.lat, target.lng), 16);
  }

  Future<void> _init() async {
    final cached = await LocationService.instance.cached();
    if (cached != null && mounted) {
      setState(() => _me = LatLng(cached.lat, cached.lng));
      if (_focus == null) _moveTo(_me!, 13);
    }
    await _locate(moveCamera: cached == null);
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _locate({bool moveCamera = true}) async {
    setState(() => _locating = true);
    final res = await LocationService.instance.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationProblem = res.ok ? null : res.status;
    });
    if (!res.ok) return;

    final fix = res.fix!;
    final point = LatLng(fix.lat, fix.lng);
    setState(() => _me = point);
    if (moveCamera && _focus == null) _moveTo(point, 14);

    final auth = context.read<AuthProvider>();
    if (!(auth.currentUser?.ghostMode ?? false)) {
      unawaited(auth.updateLocation(fix.lat, fix.lng, fix.city));
    }
    _loadTravelers(point);
  }

  void _moveTo(LatLng point, double zoom) {
    if (!_mapReady) return;
    _map.move(point, zoom);
  }

  /// [silent] = background refresh: no spinner and the "Search this area" chip
  /// is left alone.
  Future<void> _loadTravelers(LatLng around, {bool silent = false}) async {
    _searchCenter = around;
    if (!silent) {
      setState(() {
        _loadingTravelers = true;
        _showSearchArea = false;
      });
    }
    try {
      final list = await _repo.nearby(around.latitude, around.longitude, radiusKm: 100);
      if (!mounted) return;
      setState(() {
        _travelers = list;
        // Keep the open card's "last live … ago" fresh.
        final open = _selected;
        if (open != null) {
          for (final t in list) {
            if (t.id == open.id) _selected = t;
          }
        }
      });
    } catch (_) {
      // Keep showing the last pins when a background refresh fails.
      if (mounted && !silent) setState(() => _travelers = const []);
    } finally {
      if (mounted && !silent) setState(() => _loadingTravelers = false);
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<void> _runSearch() async {
    final q = _searchController.text.trim();
    if (q.length < 2) return;
    _searchFocus.unfocus();
    setState(() => _searching = true);
    final res = await LocationService.instance.searchPlaces(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _searching = false;
    });
    if (res.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No places found. Try another name.')),
      );
    }
  }

  void _pickPlace(PlaceResult p) {
    final point = LatLng(p.lat, p.lng);
    setState(() {
      _results = const [];
      _selected = null;
    });
    _moveTo(point, 13);
    _loadTravelers(point);
  }

  // ── Ghost mode ──────────────────────────────────────────────────────────────

  Future<void> _toggleGhost() async {
    final auth = context.read<AuthProvider>();
    final enable = !(auth.currentUser?.ghostMode ?? false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.setGhostMode(enable);
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(enable
            ? 'Ghost Mode on: you are hidden from other travelers.'
            : 'Ghost Mode off: nearby travelers can see you.'),
      ));
      if (!enable) {
        _locate(moveCamera: false);
        LocationSharingService.instance.refreshSoon();
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not change Ghost Mode. Check your connection.')),
      );
    }
  }

  // ── Chat requests ───────────────────────────────────────────────────────────

  Future<void> _requestChat(Traveler t) async {
    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actionBusy = true);
    try {
      final status = await chat.sendChatRequest(t.id);
      messenger.showSnackBar(SnackBar(
        content: Text(status == 'accepted'
            ? 'You can chat with ${t.name} now! 🎉'
            : "Chat request sent to ${t.name}. You'll be notified when they accept."),
      ));
    } on ChatRequestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send the request. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelRequest(Traveler t) async {
    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actionBusy = true);
    try {
      await chat.cancelChatRequest(t.id);
      messenger.showSnackBar(SnackBar(content: Text('Request to ${t.name} cancelled.')));
    } on ChatRequestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not cancel. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _respond(Traveler t, {required bool accept}) async {
    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final req = chat.incomingFrom(t.id);
    if (req == null) return;
    setState(() => _actionBusy = true);
    try {
      await chat.respondToChatRequest(req, accept: accept);
      messenger.showSnackBar(SnackBar(
        content: Text(accept
            ? 'You can now chat with ${t.name}. 🎉'
            : "Declined ${t.name}'s request."),
      ));
      if (accept && mounted) _openChat(t);
    } on ChatRequestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not do that. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _openChat(Traveler t) {
    context.read<ChatProvider>().ensureConversation(
          peerId: t.id,
          name: t.name,
          imageUrl: t.imageUrl,
          isVerified: t.isVerified,
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          args: ChatRoomArgs(
            peerId: t.id,
            name: t.name,
            imageUrl: t.imageUrl,
            isVerified: t.isVerified,
          ),
        ),
      ),
    );
  }

  void _openProfile(Traveler t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TravelerProfileScreen(traveler: t)),
    );
  }

  // ── Tiles ───────────────────────────────────────────────────────────────────

  TileLayer _tileLayer(bool isDark) {
    final key = Env.mapTilerKey;
    String url;
    List<String> subdomains = const [];
    int maxNative = 19;

    if (key.isNotEmpty) {
      url = switch (_style) {
        _MapStyle.standard =>
          'https://api.maptiler.com/maps/${isDark ? 'streets-v2-dark' : 'streets-v2'}/{z}/{x}/{y}.png?key=$key',
        _MapStyle.satellite =>
          'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$key',
        _MapStyle.terrain =>
          'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}.png?key=$key',
      };
      maxNative = 20;
    } else {
      switch (_style) {
        case _MapStyle.standard:
          url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
        case _MapStyle.satellite:
          url =
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
        case _MapStyle.terrain:
          url = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
          subdomains = const ['a', 'b', 'c'];
          maxNative = 17;
      }
    }

    return TileLayer(
      urlTemplate: url,
      subdomains: subdomains,
      maxNativeZoom: maxNative,
      userAgentPackageName: 'rovlo.com',
      keepBuffer: 2,
    );
  }

  String get _attribution {
    if (Env.mapTilerKey.isNotEmpty) return '© MapTiler © OpenStreetMap contributors';
    return switch (_style) {
      _MapStyle.standard => '© OpenStreetMap contributors',
      _MapStyle.satellite => 'Tiles © Esri',
      _MapStyle.terrain => '© OpenTopoMap (CC-BY-SA) © OpenStreetMap contributors',
    };
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = context.rovlo.card;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final ghost = context.select<AuthProvider, bool>((a) => a.currentUser?.ghostMode ?? false);
    final selectedId = _selected?.id;
    final link = context.select<ChatProvider, ChatLink>(
      (c) => selectedId == null ? ChatLink.none : c.linkWith(selectedId),
    );

    final markers = <Marker>[
      if (_me != null && !ghost)
        Marker(
          point: _me!,
          width: 44,
          height: 44,
          child: _MyLocationDot(color: primary),
        ),
      for (final t in _travelers)
        if (t.latitude != null && t.longitude != null)
          Marker(
            point: LatLng(t.latitude!, t.longitude!),
            width: 84,
            height: 74,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected = t);
              },
              child: _TravelerPin(
                traveler: t,
                selected: _selected?.id == t.id,
                color: primary,
                isDark: isDark,
              ),
            ),
          ),
      if (_focus != null)
        Marker(
          point: LatLng(_focus!.lat, _focus!.lng),
          width: 120,
          height: 84,
          alignment: Alignment.topCenter,
          child: _SharedPin(label: _focus!.label),
        ),
    ];

    return Stack(
      children: [
        // ── Map ────────────────────────────────────────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _focus != null
                  ? LatLng(_focus!.lat, _focus!.lng)
                  : (_me ?? _fallbackCenter),
              initialZoom: _focus != null ? 16 : (_me != null ? 13 : 4.5),
              minZoom: 2,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapReady = true;
                if (_focus != null) {
                  _moveTo(LatLng(_focus!.lat, _focus!.lng), 16);
                } else if (_me != null) {
                  _moveTo(_me!, 13);
                }
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && !_showSearchArea && mounted) {
                  setState(() => _showSearchArea = true);
                }
              },
              onTap: (_, __) => setState(() {
                _selected = null;
                _results = const [];
              }),
            ),
            children: [
              _tileLayer(isDark),
              MarkerLayer(markers: markers),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 8,
                    bottom: _selected != null ? 190 : 96,
                  ),
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _attribution,
                        style: const TextStyle(fontSize: 9.5, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Search + status ────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _runSearch,
                        icon: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search, color: AppColors.accent),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                          decoration: const InputDecoration(
                            hintText: 'Search a city or place…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _locating ? null : () => _locate(),
                        icon: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: Icon(Icons.place_outlined, color: primary),
                        title: Text(
                          _results[i].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => _pickPlace(_results[i]),
                      ),
                    ),
                  ),
                if (_locationProblem != null) ...[
                  const SizedBox(height: 8),
                  _LocationBanner(
                    status: _locationProblem!,
                    onTap: () async {
                      if (_locationProblem == LocationStatus.serviceOff ||
                          _locationProblem == LocationStatus.deniedForever) {
                        await LocationService.instance.openSettings(_locationProblem!);
                      } else {
                        await _locate();
                      }
                    },
                  ),
                ],
                if (_showSearchArea) ...[
                  const SizedBox(height: 8),
                  ActionChip(
                    avatar: _loadingTravelers
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Search this area'),
                    backgroundColor: cardColor,
                    onPressed: () {
                      if (_mapReady) _loadTravelers(_map.camera.center);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Zoom / style / ghost controls ──────────────────────────────────
        Positioned(
          right: 16,
          top: 100,
          child: SafeArea(
            child: Column(
              children: [
                _FloatingControl(
                  icon: Icons.add,
                  onTap: () {
                    if (_mapReady) _map.move(_map.camera.center, _map.camera.zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _FloatingControl(
                  icon: Icons.remove,
                  onTap: () {
                    if (_mapReady) _map.move(_map.camera.center, _map.camera.zoom - 1);
                  },
                ),
                const SizedBox(height: 16),
                _FloatingControl(
                  icon: switch (_style) {
                    _MapStyle.standard => Icons.map,
                    _MapStyle.satellite => Icons.satellite_alt_outlined,
                    _MapStyle.terrain => Icons.terrain,
                  },
                  onTap: () {
                    setState(() {
                      _style = _MapStyle.values[(_style.index + 1) % _MapStyle.values.length];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text('${_style.name[0].toUpperCase()}${_style.name.substring(1)} map'),
                    ));
                  },
                ),
                const SizedBox(height: 16),
                _FloatingControl(
                  icon: ghost ? Icons.visibility_off : Icons.visibility,
                  active: ghost,
                  onTap: _toggleGhost,
                ),
              ],
            ),
          ),
        ),

        // ── Location shared in a chat ──────────────────────────────────────
        if (_focus != null && _selected == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _SharedLocationCard(
              target: _focus!,
              onClose: () => AppNavigation.mapFocus.value = null,
            ).animate().slideY(begin: 0.3, curve: Curves.easeOutBack).fadeIn(),
          ),

        // ── Selected traveller card ────────────────────────────────────────
        if (_selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _SelectedCard(
              key: ValueKey(_selected!.id),
              traveler: _selected!,
              link: link,
              busy: _actionBusy,
              onRequest: () => _requestChat(_selected!),
              onCancel: () => _cancelRequest(_selected!),
              onAccept: () => _respond(_selected!, accept: true),
              onDecline: () => _respond(_selected!, accept: false),
              onMessage: () => _openChat(_selected!),
              onProfile: () => _openProfile(_selected!),
              onClose: () => setState(() => _selected = null),
            ).animate().slideY(begin: 0.3, curve: Curves.easeOutBack).fadeIn(),
          ),
      ],
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}

class _TravelerPin extends StatelessWidget {
  const _TravelerPin({
    required this.traveler,
    required this.selected,
    required this.color,
    required this.isDark,
  });

  final Traveler traveler;
  final bool selected;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 48.0 : 38.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: selected ? color : Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                image: DecorationImage(
                  image: CachedNetworkImageProvider(traveler.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: OnlineDot(
                userId: traveler.id,
                size: selected ? 14 : 12,
                borderColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? color : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3),
            ],
          ),
          child: Text(
            traveler.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white : AppColors.lightTextPrimary),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    super.key,
    required this.traveler,
    required this.link,
    required this.busy,
    required this.onRequest,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
    required this.onMessage,
    required this.onProfile,
    required this.onClose,
  });

  final Traveler traveler;
  final ChatLink link;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onMessage;
  final VoidCallback onProfile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = context.rovlo.textSecondary;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onProfile,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: traveler.imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(width: 64, height: 64, color: Colors.grey.shade300),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: OnlineDot(
                        userId: traveler.id,
                        size: 16,
                        borderColor: context.rovlo.card,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              traveler.nameWithAge,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (traveler.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, color: primary, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      OnlineBuilder(
                        userId: traveler.id,
                        builder: (context, online) => Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: online ? OnlineDot.green : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                online
                                    ? 'Online now · live'
                                    : (traveler.lastLiveLabel.isEmpty
                                        ? 'Offline'
                                        : 'Live location · ${traveler.lastLiveLabel}'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: online ? OnlineDot.green : textSec,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (traveler.location.isNotEmpty)
                        Text(
                          'In ${traveler.location}',
                          style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (traveler.distanceLabel.isNotEmpty)
                        Text(
                          traveler.distanceLabel,
                          style: TextStyle(fontSize: 11, color: textSec.withValues(alpha: 0.75)),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, color: textSec, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _actions(context, primary, textSec),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Color primary, Color textSec) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const height = Size.fromHeight(46);

    Widget filled(String label, IconData icon, VoidCallback onTap) => ElevatedButton.icon(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: height,
            shape: shape,
            elevation: 0,
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        );

    switch (link) {
      case ChatLink.none:
        return filled('Request to chat', Icons.chat_bubble_outline, onRequest);
      case ChatLink.sent:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                style: OutlinedButton.styleFrom(minimumSize: height, shape: shape),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Request sent'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: busy ? null : onCancel, child: const Text('Cancel')),
          ],
        );
      case ChatLink.received:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${traveler.name} wants to chat with you',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(minimumSize: height, shape: shape),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: filled('Accept', Icons.check_rounded, onAccept),
                ),
              ],
            ),
          ],
        );
      case ChatLink.connected:
        return filled('Message', Icons.chat_bubble, onMessage);
      case ChatLink.declined:
        return OutlinedButton.icon(
          onPressed: null,
          style: OutlinedButton.styleFrom(minimumSize: height, shape: shape),
          icon: const Icon(Icons.block, size: 18),
          label: const Text('Request declined'),
        );
    }
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.status, required this.onTap});

  final LocationStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (text, action) = switch (status) {
      LocationStatus.serviceOff => ('Location is turned off.', 'Turn on'),
      LocationStatus.deniedForever => ('Location permission is blocked.', 'Settings'),
      LocationStatus.denied => ('Allow location to see travelers near you.', 'Allow'),
      _ => ('Could not get your position.', 'Retry'),
    };
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _FloatingControl extends StatelessWidget {
  const _FloatingControl({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? primary : context.rovlo.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: active ? Colors.white : primary, size: 20),
      ),
    );
  }
}

/// Red pin for a location that was shared in a chat.
class _SharedPin extends StatelessWidget {
  const _SharedPin({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(Icons.location_on, color: Color(0xFFE53935), size: 46),
      ],
    );
  }
}

class _SharedLocationCard extends StatelessWidget {
  const _SharedLocationCard({required this.target, required this.onClose});

  final MapFocusTarget target;
  final VoidCallback onClose;

  Future<void> _directions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.lat},${target.lng}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open directions on this phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSec = context.rovlo.textSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFFE53935), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  'Shared in chat',
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _directions(context),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Directions'),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: textSec, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
