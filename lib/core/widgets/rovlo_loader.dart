import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rovlo's signature loader — the letter "R" drawn in one continuous stroke.
///
/// A faint "R" track sits in place while a glowing amber dot traces over it,
/// pulling a tapered brand-colour trail — like the Rovlo logo signing itself.
/// Pure CustomPainter, no assets. Drop it anywhere a spinner would go:
///
///   const RovloLoader()                     // default 56px, teal trail
///   const RovloLoader(size: 26, trailColor: Colors.white)  // inside buttons
class RovloLoader extends StatefulWidget {
  const RovloLoader({
    super.key,
    this.size = 56,
    this.trailColor = AppColors.primary,
    this.dotColor = AppColors.accent,
    this.trackColor,
  });

  final double size;
  final Color trailColor;
  final Color dotColor;

  /// Colour of the faint full-"R" guide. Defaults to a low-alpha trail colour.
  final Color? trackColor;

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
      duration: const Duration(milliseconds: 1600),
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
          painter: _RSignaturePainter(
            t: _controller.value,
            trailColor: widget.trailColor,
            dotColor: widget.dotColor,
            trackColor:
                widget.trackColor ?? widget.trailColor.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

class _RSignaturePainter extends CustomPainter {
  _RSignaturePainter({
    required this.t,
    required this.trailColor,
    required this.dotColor,
    required this.trackColor,
  });

  final double t;
  final Color trailColor;
  final Color dotColor;
  final Color trackColor;

  /// The "R", designed in a 100×100 box as ONE continuous stroke:
  /// up the stem, around the bowl, then kick out the leg.
  static Path _rPath(Size size) {
    const inset = 10.0; // breathing room inside the 100-box
    final s = size.shortestSide / 100.0;
    final dx = (size.width - size.shortestSide) / 2;
    final dy = (size.height - size.shortestSide) / 2;

    Offset p(double x, double y) => Offset(dx + x * s, dy + y * s);

    final path = Path()..moveTo(p(30, 100 - inset).dx, p(30, 100 - inset).dy);
    path.lineTo(p(30, inset + 4).dx, p(30, inset + 4).dy); // stem up
    path.cubicTo(
      p(80, inset).dx, p(80, inset).dy, // bowl out to the right…
      p(80, 52).dx, p(80, 52).dy,
      p(30, 50).dx, p(30, 50).dy, // …and back to the stem
    );
    path.lineTo(p(74, 100 - inset).dx, p(74, 100 - inset).dy); // the leg
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _rPath(size);
    final metric = path.computeMetrics().first;
    final length = metric.length;

    final trackStroke = size.shortestSide * 0.055;
    final trailStroke = size.shortestSide * 0.085;

    // 1. Faint guide "R" — always visible so the letterform reads instantly.
    canvas.drawPath(
      path,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 2. The moving trail. The head travels the full length plus one trail
    // length, so the tail gracefully slides off the leg before the loop
    // restarts — a complete "signature" every cycle.
    final trailLen = length * 0.38;
    final headDist = t * (length + trailLen);
    final start = (headDist - trailLen).clamp(0.0, length);
    final end = headDist.clamp(0.0, length);

    if (end > start) {
      // Taper: short overlapping segments with ramping alpha ≈ a comet tail.
      const segments = 14;
      final segLen = (end - start) / segments;
      for (var i = 0; i < segments; i++) {
        final alpha = (i + 1) / segments;
        canvas.drawPath(
          metric.extractPath(start + i * segLen, start + (i + 1) * segLen),
          Paint()
            ..color = trailColor.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = trailStroke * (0.55 + 0.45 * alpha)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 3. The glowing amber pen-tip. It fades out while the tail finishes,
    // then reappears at the foot of the stem for the next signature.
    final dotFade =
        headDist <= length ? 1.0 : (1 - (headDist - length) / trailLen);
    if (dotFade <= 0) return;

    final tangent = metric.getTangentForOffset(min(headDist, length));
    if (tangent == null) return;

    final pulse = 1 + 0.15 * sin(4 * pi * t);
    final dotR = size.shortestSide * 0.075 * pulse;
    final dotCenter = tangent.position;

    canvas.drawCircle(
      dotCenter,
      dotR * 1.9,
      Paint()
        ..color = dotColor.withValues(alpha: 0.45 * dotFade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR),
    );
    canvas.drawCircle(
      dotCenter,
      dotR,
      Paint()..color = dotColor.withValues(alpha: dotFade),
    );
    canvas.drawCircle(
      dotCenter,
      dotR * 0.4,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * dotFade),
    );
  }

  @override
  bool shouldRepaint(covariant _RSignaturePainter old) => old.t != t;
}
