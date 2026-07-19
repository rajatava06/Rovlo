import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  GoogleMapController? _googleMapController;

  bool get _useMockMap {
    // Return true on all platforms to display the beautifully designed custom vector map
    // and avoid crashes due to missing Google Maps API keys on Android/iOS.
    return true;
  }

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
        _askedLocation = true;
        _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);
      });
      _moveGoogleMapCamera();
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

  void _moveGoogleMapCamera() {
    if (_googleMapController != null && _locationAllowed) {
      _googleMapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_deviceLatitude, _deviceLongitude),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  void _onPinTap(Traveler traveler) {
    setState(() {
      _selectedTraveler = traveler;
    });
  }

  void _zoomIn() {
    if (_googleMapController != null) {
      _googleMapController!.animateCamera(CameraUpdate.zoomIn());
    } else {
      setState(() {
        if (_zoom < 2.0) _zoom += 0.15;
      });
    }
  }

  void _zoomOut() {
    if (_googleMapController != null) {
      _googleMapController!.animateCamera(CameraUpdate.zoomOut());
    } else {
      setState(() {
        if (_zoom > 0.6) _zoom -= 0.15;
      });
    }
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
            _mapOffset = const Offset(-50, -50);
            _zoom = 1.0;
            _selectedTraveler = null;
          });
          _moveGoogleMapCamera();
        } catch (_) {
          setState(() {
            _locationAllowed = true;
            _askedLocation = true;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Map centered on default Barcelona coordinates.')),
        );
      }
    } else {
      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _deviceLatitude = position.latitude;
          _deviceLongitude = position.longitude;
          _mapOffset = const Offset(-50, -50);
          _zoom = 1.0;
          _selectedTraveler = null;
          _generateNearbyTravelers(_deviceLatitude, _deviceLongitude);
        });
        _moveGoogleMapCamera();
      } catch (_) {
        setState(() {
          _mapOffset = const Offset(-50, -50);
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
        // ── Map Layer (Real Google Maps or Vector Fallback) ──
        Positioned.fill(
          child: _useMockMap
              ? GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _mapOffset += details.delta;
                    });
                  },
                  child: Container(
                    color: isDark ? const Color(0xFF070E17) : const Color(0xFFEFECE6),
                    width: double.infinity,
                    height: double.infinity,
                    child: ClipRect(
                      child: Transform.translate(
                        offset: _mapOffset,
                        child: Transform.scale(
                          scale: _zoom,
                          child: CustomPaint(
                            painter: _MapPainter(
                              isDark: isDark,
                              mapStyle: _mapStyle,
                            ),
                            child: Stack(
                              children: [
                                // GPS center indicator
                                if (_locationAllowed && !_ghostMode)
                                  Positioned(
                                    left: 400,
                                    top: 400,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: primaryPeach.withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ..._pins.map((pin) {
                                  final isSelected = _selectedTraveler?.name == pin.traveler.name;
                                  return Positioned(
                                    left: pin.offset.dx,
                                    top: pin.offset.dy,
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
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_deviceLatitude, _deviceLongitude),
                    zoom: 14.0,
                  ),
                  myLocationEnabled: !_ghostMode && _locationAllowed,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  mapType: _mapStyle == 'Standard'
                      ? MapType.normal
                      : _mapStyle == 'Satellite'
                          ? MapType.satellite
                          : MapType.terrain,
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                    _moveGoogleMapCamera();
                  },
                  markers: _pins.map((pin) {
                    return Marker(
                      markerId: MarkerId(pin.traveler.name),
                      position: LatLng(pin.latitude, pin.longitude),
                      onTap: () => _onPinTap(pin.traveler),
                    );
                  }).toSet(),
                ),
        ),

        // ── Floating Search Bar ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
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
                        hintText: 'Search locations near Bali...',
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
    final Paint landPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF0F1B2C) : const Color(0xFF8B9B7E))
          : (isDark ? const Color(0xFF0B1420) : const Color(0xFFECE7DF))
      ..style = PaintingStyle.fill;

    final Paint waterPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF060B12) : const Color(0xFF5A7CA6))
          : (isDark ? const Color(0xFF040911) : const Color(0xFFB5D0EB))
      ..style = PaintingStyle.fill;

    final Paint gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint greenPaint = Paint()
      ..color = mapStyle == 'Satellite'
          ? (isDark ? const Color(0xFF142C23) : const Color(0xFF637C54))
          : (isDark ? const Color(0xFF0D1E16) : const Color(0xFFD4E6CF))
      ..style = PaintingStyle.fill;

    canvas.drawRect(const Rect.fromLTWH(-1000, -1000, 3000, 3000), waterPaint);

    final Path landPath = Path()
      ..moveTo(100, 450)
      ..quadraticBezierTo(200, 150, 400, 200)
      ..quadraticBezierTo(600, 250, 800, 380)
      ..quadraticBezierTo(900, 500, 700, 580)
      ..quadraticBezierTo(500, 620, 350, 550)
      ..quadraticBezierTo(200, 600, 100, 450)
      ..close();
    canvas.drawPath(landPath, landPaint);

    final Path greenPath1 = Path()
      ..moveTo(250, 300)
      ..quadraticBezierTo(300, 220, 400, 280)
      ..quadraticBezierTo(350, 380, 250, 300)
      ..close();
    canvas.drawPath(greenPath1, greenPaint);

    final Path greenPath2 = Path()
      ..moveTo(480, 320)
      ..quadraticBezierTo(580, 300, 550, 450)
      ..quadraticBezierTo(420, 400, 480, 320)
      ..close();
    canvas.drawPath(greenPath2, greenPaint);

    for (double i = -1000; i < 2000; i += 80) {
      canvas.drawLine(Offset(i, -1000), Offset(i, 2000), gridPaint);
      canvas.drawLine(Offset(-1000, i), Offset(2000, i), gridPaint);
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
