import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A slow, always-moving multi-colour gradient with drifting light "orbs".
///
/// Used as the animated fallback behind the Welcome screen when no background
/// video is present, and anywhere a lively brand backdrop is wanted. Pure
/// Flutter — no assets required.
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

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
              begin: Alignment(cos(angle), sin(angle)),
              end: Alignment(-cos(angle), -sin(angle)),
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
    final orbs = <_Orb>[
      _Orb(0.2, 0.3, 0.32, Colors.white.withValues(alpha: 0.14)),
      _Orb(0.8, 0.2, 0.26, AppColors.accent.withValues(alpha: 0.16)),
      _Orb(0.7, 0.8, 0.38, AppColors.secondary.withValues(alpha: 0.18)),
      _Orb(0.15, 0.85, 0.22, Colors.white.withValues(alpha: 0.10)),
    ];
    for (var i = 0; i < orbs.length; i++) {
      final o = orbs[i];
      final phase = t * 2 * pi + i;
      final dx = (o.x + 0.05 * cos(phase)) * size.width;
      final dy = (o.y + 0.05 * sin(phase)) * size.height;
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

class _Orb {
  const _Orb(this.x, this.y, this.r, this.color);
  final double x;
  final double y;
  final double r;
  final Color color;
}
