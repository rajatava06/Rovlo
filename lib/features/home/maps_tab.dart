import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  // Coordinates on our mock map canvas
  final List<MapPin> _pins = [
    MapPin(
      traveler: SampleTravelers.list[0], // Julian
      offset: const Offset(200, 320),
    ),
    MapPin(
      traveler: SampleTravelers.list[1], // Elena
      offset: const Offset(420, 240),
    ),
    MapPin(
      traveler: SampleTravelers.list[2], // Mark & Suzi
      offset: const Offset(310, 520),
    ),
    MapPin(
      traveler: SampleTravelers.list[3], // Sophia
      offset: const Offset(550, 410),
    ),
  ];

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

  void _recenter() {
    if (!_askedLocation) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rovlo wants to use your location'),
          content: const Text('Allow Rovlo to access this device\'s location to show nearby travelers on the map.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _askedLocation = true;
                  _locationAllowed = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location permission denied. Map cannot show your current position.')),
                );
              },
              child: const Text('Don\'t Allow'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _askedLocation = true;
                  _locationAllowed = true;
                  _mapOffset = const Offset(-50, -50);
                  _zoom = 1.0;
                  _selectedTraveler = null;
                });
              },
              child: const Text('Allow'),
            ),
          ],
        ),
      );
    } else {
      if (!_locationAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Map cannot show your current position.')),
        );
      } else {
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
        // ── Map Canvas Container ────────────────────────────────────────────────
        GestureDetector(
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
                      children: _pins.map((pin) {
                        final isSelected = _selectedTraveler?.name == pin.traveler.name;
                        return Positioned(
                          left: pin.offset.dx,
                          top: pin.offset.dy,
                          child: GestureDetector(
                            onTap: () => _onPinTap(pin.traveler),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glowing ring for selected traveler
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
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Floating Search Bar (Enabled) ────────────────────────────────────────
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

        // ── Floating Map Style & Zoom Controls ──────────────────────────────────
        Positioned(
          right: 16,
          top: 100,
          child: Column(
            children: [
              // Zoom In
              _FloatingControl(icon: Icons.add, onTap: _zoomIn),
              const SizedBox(height: 8),
              // Zoom Out
              _FloatingControl(icon: Icons.remove, onTap: _zoomOut),
              const SizedBox(height: 16),
              // Style Toggle (Standard / Satellite / Terrain)
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
              // Ghost Mode Toggle
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

        // ── Selected Traveler Details Card Overlay ──────────────────────────────
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
                  // Photo
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
                  // Name + Location info
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
                  // Message Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opening chat with ${_selectedTraveler!.name}...'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5A2B), // Brown color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          elevation: 0,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTraveler = null;
                          });
                        },
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: textSecColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
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
        child: Icon(icon, color: primaryPeach, size: 22),
      ),
    );
  }
}

class MapPin {
  final Traveler traveler;
  final Offset offset;

  const MapPin({required this.traveler, required this.offset});
}

class _MapPainter extends CustomPainter {
  final bool isDark;
  final String mapStyle;

  const _MapPainter({required this.isDark, required this.mapStyle});

  @override
  void paint(Canvas canvas, Size size) {
    // Determine canvas colors based on dark mode & mapStyle
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

    // Draw background (water)
    canvas.drawRect(const Rect.fromLTWH(-1000, -1000, 3000, 3000), waterPaint);

    // Draw mock Island geography (Bali shape outline approximation)
    final Path landPath = Path()
      ..moveTo(100, 450)
      ..quadraticBezierTo(200, 150, 400, 200)
      ..quadraticBezierTo(600, 250, 800, 380)
      ..quadraticBezierTo(900, 500, 700, 580)
      ..quadraticBezierTo(500, 620, 350, 550)
      ..quadraticBezierTo(200, 600, 100, 450)
      ..close();
    canvas.drawPath(landPath, landPaint);

    // Draw some green zones/parks (if Standard or Terrain or Satellite)
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

    // Draw grid lines
    for (double i = -1000; i < 2000; i += 80) {
      canvas.drawLine(Offset(i, -1000), Offset(i, 2000), gridPaint);
      canvas.drawLine(Offset(-1000, i), Offset(2000, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
