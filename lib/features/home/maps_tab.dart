import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';

class MapsTab extends StatefulWidget {
  const MapsTab({super.key});

  @override
  State<MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends State<MapsTab> {
  Offset _mapOffset = const Offset(-50, -50);
  double _zoom = 1.0;
  Traveler? _selectedTraveler;
  String _mapStyle = 'Standard'; // Standard, Satellite, Terrain
  bool _ghostMode = false;
  bool _askedLocation = false;
  bool _locationAllowed = false;

  double _deviceLatitude = 41.3851; // Default to Barcelona
  double _deviceLongitude = 2.1734;

  final List<MapPin> _pins = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _deviceLatitude = position.latitude;
        _deviceLongitude = position.longitude;
        _locationAllowed = true;
        _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);
      });
    } catch (_) {
      // Geolocator failed or not supported on this platform
    }
  }

  void _generateNearbyTravelers(double lat, double lng) {
    final List<Traveler> rawTravelers = SampleTravelers.list;
    _pins.clear();
    
    // Julian
    _pins.add(MapPin(
      traveler: rawTravelers[0],
      latitude: lat + 0.002,
      longitude: lng - 0.003,
      offset: const Offset(200, 320),
    ));
    
    // Elena
    _pins.add(MapPin(
      traveler: rawTravelers[1],
      latitude: lat - 0.003,
      longitude: lng + 0.004,
      offset: const Offset(420, 240),
    ));
    
    // Mark & Suzi
    _pins.add(MapPin(
      traveler: rawTravelers[2],
      latitude: lat + 0.004,
      longitude: lng + 0.002,
      offset: const Offset(310, 520),
    ));
  }

  void _onPinTap(Traveler traveler) {
    setState(() {
      _selectedTraveler = traveler;
    });
  }

  void _zoomIn() {
    setState(() {
      if (_zoom < 2.0) _zoom += 0.15;
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoom > 0.6) _zoom -= 0.15;
    });
  }

  Future<void> _recenter() async {
    if (!_locationAllowed) {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        try {
          final position = await Geolocator.getCurrentPosition();
          setState(() {
            _deviceLatitude = position.latitude;
            _deviceLongitude = position.longitude;
            _locationAllowed = true;
            _askedLocation = true;
            _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);
            _mapOffset = Offset.zero;
            _zoom = 1.0;
            _selectedTraveler = null;
          });
        } catch (_) {
          setState(() {
            _locationAllowed = true;
            _askedLocation = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Map centered on default coordinates.')),
          );
        }
      }
    } else {
      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _deviceLatitude = position.latitude;
          _deviceLongitude = position.longitude;
          _mapOffset = Offset.zero;
          _zoom = 1.0;
          _selectedTraveler = null;
          _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);
        });
      } catch (_) {
        setState(() {
          _mapOffset = Offset.zero;
          _zoom = 1.0;
          _selectedTraveler = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecColor = context.rovlo.textSecondary;
    final cardColor = context.rovlo.card;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Stack(
      children: [
        // ── Map Layer (Interactive Street Vector & Radar Map) ──
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              // Position pins relative to current screen size
              final dynamicPins = [
                MapPin(
                  traveler: SampleTravelers.list[0],
                  latitude: _deviceLatitude + 0.002,
                  longitude: _deviceLongitude - 0.003,
                  offset: Offset(w * 0.25, h * 0.35),
                ),
                MapPin(
                  traveler: SampleTravelers.list[1],
                  latitude: _deviceLatitude - 0.003,
                  longitude: _deviceLongitude + 0.004,
                  offset: Offset(w * 0.68, h * 0.28),
                ),
                MapPin(
                  traveler: SampleTravelers.list[2],
                  latitude: _deviceLatitude + 0.004,
                  longitude: _deviceLongitude + 0.002,
                  offset: Offset(w * 0.45, h * 0.62),
                ),
              ];

              return GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _mapOffset += details.delta;
                  });
                },
                child: Container(
                  color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFE9ECEF),
                  width: double.infinity,
                  height: double.infinity,
                  child: ClipRect(
                    child: Transform.translate(
                      offset: _mapOffset,
                      child: Transform.scale(
                        scale: _zoom,
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _MapPainter(
                            isDark: isDark,
                            mapStyle: _mapStyle,
                          ),
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: Stack(
                              children: [
                                // GPS Current Location Pulsing Radar
                                if (!_ghostMode)
                                  Positioned(
                                    left: w * 0.5 - 20,
                                    top: h * 0.5 - 20,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: primaryPeach.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryPeach.withValues(alpha: 0.6),
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: primaryPeach,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryPeach.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Nearby Traveler Pins
                                ...dynamicPins.map((pin) {
                                  final isSelected = _selectedTraveler?.name == pin.traveler.name;
                                  return Positioned(
                                    left: pin.offset.dx - 20,
                                    top: pin.offset.dy - 30,
                                    child: GestureDetector(
                                      onTap: () => _onPinTap(pin.traveler),
                                      child: _buildMockPinWidget(pin, isSelected, primaryPeach, isDark),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Floating Search Bar & Live GPS Chip ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                        onPressed: () {},
                        icon: const Icon(Icons.search, color: AppColors.accent),
                      ),
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search locations near you...',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _recenter,
                        icon: const Icon(Icons.my_location, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Live GPS Location Indicator Badge
                GestureDetector(
                  onTap: _recenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryPeach.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed, size: 13, color: primaryPeach),
                        const SizedBox(width: 6),
                        Text(
                          _locationAllowed
                              ? '📍 GPS: ${_deviceLatitude.toStringAsFixed(4)}, ${_deviceLongitude.toStringAsFixed(4)}'
                              : '📍 Tap to locate device position',
                          style: TextStyle(
                            fontSize: 11,
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
        ),

        // ── Floating Map Style & Zoom Controls ──
        Positioned(
          right: 16,
          top: 100,
          child: Column(
            children: [
              _FloatingControl(icon: Icons.add, onTap: _zoomIn),
              const SizedBox(height: 8),
              _FloatingControl(icon: Icons.remove, onTap: _zoomOut),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_mapStyle == 'Standard') {
                      _mapStyle = 'Satellite';
                    } else if (_mapStyle == 'Satellite') {
                      _mapStyle = 'Terrain';
                    } else {
                      _mapStyle = 'Standard';
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text('Switched to $_mapStyle Map Mode'),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    _mapStyle == 'Standard'
                        ? Icons.map
                        : _mapStyle == 'Satellite'
                            ? Icons.satellite_outlined
                            : Icons.terrain,
                    color: primaryPeach,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _ghostMode = !_ghostMode;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(_ghostMode
                          ? 'Ghost Mode enabled: Your location is now hidden from other travelers.'
                          : 'Ghost Mode disabled: You are visible to nearby travelers.'),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _ghostMode ? (isDark ? Colors.grey.shade800 : Colors.grey.shade400) : cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    _ghostMode ? Icons.visibility_off : Icons.visibility,
                    color: _ghostMode ? Colors.white : primaryPeach,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Selected Traveler Details Card Overlay ──
        if (_selectedTraveler != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(_selectedTraveler!.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedTraveler!.name}, ${_selectedTraveler!.age}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 13, color: AppColors.accent),
                            const SizedBox(width: 2),
                            Text(
                              'In ${_selectedTraveler!.location}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '0.5 km away from you',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Like & Close Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: primaryPeach,
                              content: Text('Liked ${_selectedTraveler!.name}! ❤️ Added to your matches.'),
                            ),
                          );
                          setState(() {
                            _selectedTraveler = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          elevation: 0,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTraveler = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          elevation: 0,
                        ),
                        child: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.3, curve: Curves.easeOutBack).fadeIn(),
          ),
      ],
    );
  }

  Widget _buildMockPinWidget(MapPin pin, bool isSelected, Color primaryPeach, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSelected ? 48 : 36,
          height: isSelected ? 48 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? primaryPeach : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.white : primaryPeach,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
              if (isSelected)
                BoxShadow(
                  color: primaryPeach.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
            ],
            image: DecorationImage(
              image: NetworkImage(pin.traveler.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? primaryPeach : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            pin.traveler.name,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.lightTextPrimary),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class MapPin {
  final Traveler traveler;
  final Offset offset;
  final double latitude;
  final double longitude;

  const MapPin({
    required this.traveler,
    required this.offset,
    required this.latitude,
    required this.longitude,
  });
}

class _MapPainter extends CustomPainter {
  final bool isDark;
  final String mapStyle;

  const _MapPainter({required this.isDark, required this.mapStyle});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ocean & Water Base Layer
    final Paint waterPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF051329) : const Color(0xFF3B6998))
          : (isDark ? const Color(0xFF0F3B66) : const Color(0xFF7FAEE3))
      ..style = PaintingStyle.fill;

    canvas.drawRect(const Rect.fromLTWH(-2000, -2000, 5000, 5000), waterPaint);

    // 2. City Landmass Layer
    final Paint landPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF142436) : const Color(0xFF6B835E))
          : (isDark ? const Color(0xFF1A293B) : const Color(0xFFF3EFE6))
      ..style = PaintingStyle.fill;

    final Path landPath = Path()
      ..moveTo(-1000, -1000)
      ..lineTo(3000, -1000)
      ..lineTo(3000, 3000)
      ..lineTo(-1000, 3000)
      ..close();
    canvas.drawPath(landPath, landPaint);

    // 3. Urban Blocks / Neighborhood Quadrants
    final Paint blockPaint = Paint()
      ..color = isDark ? const Color(0xFF22354B) : const Color(0xFFE5E0D8)
      ..style = PaintingStyle.fill;

    final List<Rect> cityBlocks = [
      const Rect.fromLTWH(80, 100, 160, 120),
      const Rect.fromLTWH(260, 100, 200, 140),
      const Rect.fromLTWH(80, 240, 140, 180),
      const Rect.fromLTWH(240, 260, 180, 160),
      const Rect.fromLTWH(440, 240, 220, 190),
      const Rect.fromLTWH(100, 440, 200, 160),
      const Rect.fromLTWH(320, 440, 240, 200),
      const Rect.fromLTWH(580, 450, 180, 180),
    ];
    for (final b in cityBlocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(8)), blockPaint);
    }

    // 4. Parks & Green Reserves
    final Paint parkPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF1B4332) : const Color(0xFF4D7C5D))
          : (isDark ? const Color(0xFF1A4D3B) : const Color(0xFFAFE1BD))
      ..style = PaintingStyle.fill;

    final List<Path> parkPaths = [
      Path()
        ..moveTo(100, 120)
        ..quadraticBezierTo(240, 80, 340, 180)
        ..quadraticBezierTo(280, 320, 140, 280)
        ..close(),
      Path()
        ..moveTo(450, 280)
        ..quadraticBezierTo(650, 240, 600, 460)
        ..quadraticBezierTo(420, 420, 450, 280)
        ..close(),
    ];
    for (final p in parkPaths) {
      canvas.drawPath(p, parkPaint);
    }

    // 5. River & Water Canal Path
    final Path riverPath = Path()
      ..moveTo(-300, 200)
      ..cubicTo(150, 320, 350, 80, 650, 350)
      ..cubicTo(850, 500, 1200, 400, 1600, 650);

    final Paint riverStroke = Paint()
      ..color = waterPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36;
    canvas.drawPath(riverPath, riverStroke);

    // 6. Primary Avenues & Golden Highways
    final Paint highwayPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? Colors.amber.shade700
          : (isDark ? const Color(0xFFFF9F0A) : const Color(0xFFF59E0B))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0;

    final List<Path> avenues = [
      Path()..moveTo(-500, 230)..lineTo(2000, 230),
      Path()..moveTo(330, -500)..lineTo(330, 2000),
      Path()..moveTo(-500, 550)..lineTo(2000, 120),
      Path()..moveTo(120, -500)..lineTo(680, 2000),
    ];
    for (final a in avenues) {
      canvas.drawPath(a, highwayPaint);
    }

    // 7. Secondary Street Grid Network
    final Paint secondaryStreetPaint = Paint()
      ..color = isDark ? const Color(0xFF384F6B) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (double i = -500; i < 2000; i += 65) {
      canvas.drawLine(Offset(i, -500), Offset(i, 2000), secondaryStreetPaint);
      canvas.drawLine(Offset(-500, i), Offset(2000, i), secondaryStreetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FloatingControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.rovlo.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Icon(icon, color: primaryPeach, size: 20),
      ),
    );
  }
}
