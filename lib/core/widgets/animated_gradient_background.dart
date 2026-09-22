import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A slow, always-moving blue gradient with drifting light orbs.
///
/// Used as the animated fallback behind the Welcome/SignIn screens when no
/// background video is present. Pure Flutter — no assets required.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    this.colors = AppColors.brandGradient,
    this.child,
  });

  final List<Color> colors;
  final Widget? child;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = t * 2 * pi;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(cos(angle) * 0.7, sin(angle) * 0.7),
              end: Alignment(-cos(angle) * 0.7, -sin(angle) * 0.7),
              colors: widget.colors,
            ),
          ),
          child: CustomPaint(
            painter: _OrbPainter(t),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = <_OrbData>[
      _OrbData(0.15, 0.20, 0.30, Colors.white.withValues(alpha: 0.16)),
      _OrbData(0.82, 0.15, 0.24, const Color(0xFF90CAF9).withValues(alpha: 0.20)),
      _OrbData(0.70, 0.80, 0.36, const Color(0xFF64B5F6).withValues(alpha: 0.18)),
      _OrbData(0.10, 0.82, 0.20, Colors.white.withValues(alpha: 0.12)),
      _OrbData(0.50, 0.50, 0.18, const Color(0xFFBBDEFB).withValues(alpha: 0.15)),
    ];

    for (var i = 0; i < orbs.length; i++) {
      final o = orbs[i];
      final phase = t * 2 * pi + i * 1.2;
      final dx = (o.x + 0.06 * cos(phase)) * size.width;
      final dy = (o.y + 0.06 * sin(phase)) * size.height;
      final radius = o.r * size.shortestSide;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [o.color, o.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => oldDelegate.t != t;
}

class _OrbData {
  const _OrbData(this.x, this.y, this.r, this.color);
  final double x;
  final double y;
  final double r;
  final Color color;
}
