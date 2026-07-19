import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'animated_gradient_background.dart';
import 'rovlo_logo.dart';

/// Rovlo's signature loader.
///
/// Concept: the amber "." from the Rovlo wordmark becomes a tiny traveller
/// orbiting a dashed route, pulling a gradient trail behind it — a journey
/// in miniature. Use [RovloLoader] anywhere a spinner would go, and
/// [RovloLoadingScreen] as the full-screen splash.
class RovloLoader extends StatefulWidget {
  const RovloLoader({
    super.key,
    this.size = 56,
    this.trailColor = AppColors.primary,
    this.dotColor = AppColors.accent,
    this.trackColor,
    this.dotOnly = false,
  });

  final double size;
  final Color trailColor;
  final Color dotColor;

  /// Colour of the faint dashed "route". Defaults to a low-alpha trail colour.
  final Color? trackColor;

  /// When true, draws only the orbiting glowing dot (no route, no trail).
  /// Used at small sizes, e.g. as the animated "." of the wordmark.
  final bool dotOnly;

  @override
  State<RovloLoader> createState() => _RovloLoaderState();
}

class _RovloLoaderState extends State<RovloLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _RoutePainter(
            t: _controller.value,
            trailColor: widget.trailColor,
            dotColor: widget.dotColor,
            trackColor: widget.trackColor ??
                widget.trailColor.withValues(alpha: 0.18),
            dotOnly: widget.dotOnly,
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.t,
    required this.trailColor,
    required this.dotColor,
    required this.trackColor,
    required this.dotOnly,
  });

  final double t;
  final Color trailColor;
  final Color dotColor;
  final Color trackColor;
  final bool dotOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.10;
    final radius = size.shortestSide / 2 - stroke * 1.6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Position of the travelling dot. Ease the rotation slightly so the dot
    // "pushes off" and "glides" instead of moving robotically.
    final eased = t - 0.06 * sin(2 * pi * t);
    final head = 2 * pi * eased - pi / 2;

    if (!dotOnly) {
      // 1. Dashed route (the itinerary).
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.45
        ..strokeCap = StrokeCap.round;
      const dashes = 14;
      for (var i = 0; i < dashes; i++) {
        final start = (i / dashes) * 2 * pi;
        canvas.drawArc(rect, start, (2 * pi / dashes) * 0.45, false, trackPaint);
      }

      // 2. Gradient trail: transparent tail -> solid brand teal at the head.
      // The trail "breathes": longer mid-cycle, shorter at the ends.
      final sweep = pi * 0.45 + pi * 0.55 * pow(sin(pi * t), 2);
      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [trailColor.withValues(alpha: 0), trailColor],
          transform: GradientRotation(head - sweep),
        ).createShader(rect);
      canvas.drawArc(rect, head - sweep, sweep, false, trailPaint);
    }

    // 3. The traveller: a glowing amber dot with a gentle pulse.
    final dotCenter =
        center + Offset(cos(head), sin(head)) * (dotOnly ? radius * 0.9 : radius);
    final pulse = 1 + 0.18 * sin(4 * pi * t);
    final dotR = stroke * (dotOnly ? 1.6 : 0.95) * pulse;

    final glowPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR * 0.9);
    canvas.drawCircle(dotCenter, dotR * 1.8, glowPaint);
    canvas.drawCircle(dotCenter, dotR, Paint()..color = dotColor);
    canvas.drawCircle(
      dotCenter,
      dotR * 0.4,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.t != t;
}

/// Full-screen branded loading screen: the wordmark's dot detaches and
/// orbits as the loader, over the animated brand gradient, with rotating
/// travel-flavoured status lines.
class RovloLoadingScreen extends StatefulWidget {
  const RovloLoadingScreen({super.key});

  @override
  State<RovloLoadingScreen> createState() => _RovloLoadingScreenState();
}

class _RovloLoadingScreenState extends State<RovloLoadingScreen> {
  static const List<String> _messages = [
    'Packing your bags…',
    'Charting the route…',
    'Finding hidden gems…',
    'Chasing the sunset…',
  ];

  int _messageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1900), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wordmark without its dot — the loader below IS the dot,
                // orbiting back to its place at the end of "Rovlo".
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const RovloLogo(fontSize: 52, showDot: false),
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 14),
                      child: RovloLoader(
                        size: 26,
                        dotOnly: true,
                        dotColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                const RovloLoader(
                  size: 64,
                  trailColor: Colors.white,
                  dotColor: AppColors.accent,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _messages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14.5,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
