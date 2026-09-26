import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Branded loading animation: the Rovlo "R" mark breathing inside a glowing
/// badge, with sonar rings expanding from it and a small traveller dot
/// orbiting on a dashed route. Cycles through friendly captions.
///
/// Pure Flutter (one controller, no assets besides the logo mark) so it is
/// cheap even on weak phones.
class RovloLoader extends StatefulWidget {
  const RovloLoader({
    super.key,
    this.messages = const ['Loading…'],
    this.size = 120,
  });

  /// Captions shown one after another under the animation.
  final List<String> messages;
  final double size;

  @override
  State<RovloLoader> createState() => _RovloLoaderState();
}

class _RovloLoaderState extends State<RovloLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _captionTimer;
  int _caption = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    if (widget.messages.length > 1) {
      _captionTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
        if (mounted) {
          setState(() => _caption = (_caption + 1) % widget.messages.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _captionTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final size = widget.size;
    final badge = size * 0.52;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.7,
          height: size * 1.7,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return CustomPaint(
                  painter: _LoaderPainter(t: t, color: primary, badge: badge),
                  child: Center(
                    child: Transform.scale(
                      // gentle breathing
                      scale: 1 + 0.06 * math.sin(t * 2 * math.pi),
                      child: Container(
                        width: badge,
                        height: badge,
                        padding: EdgeInsets.all(badge * 0.22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primary,
                              Color.lerp(primary, AppColors.primaryDark, 0.55)!,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/rovlo_icon.png',
                          color: Colors.white,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.messages[_caption % widget.messages.length],
            key: ValueKey(_caption),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Dots(controller: _c, color: primary),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.controller, required this.color});

  final Animation<double> controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (controller.value * 3 - i) % 3;
          final on = phase >= 0 && phase < 1 ? math.sin(phase * math.pi) : 0.0;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6 + 3 * on,
            height: 6 + 3 * on,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.35 + 0.65 * on),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.t, required this.color, required this.badge});

  final double t;
  final Color color;
  final double badge;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final minR = badge / 2;

    // Sonar rings: three expanding, fading circles, evenly staggered.
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = minR + (maxR * 0.78 - minR) * Curves.easeOut.transform(p);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - p) + 0.6
          ..color = color.withValues(alpha: 0.5 * (1 - p)),
      );
    }

    // Dashed route the traveller follows.
    final routeR = maxR * 0.86;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28);
    const dashes = 44;
    for (var i = 0; i < dashes; i++) {
      final a0 = 2 * math.pi * i / dashes;
      final a1 = a0 + 2 * math.pi / dashes * 0.5;
      canvas.drawArc(Rect.fromCircle(center: c, radius: routeR), a0, a1 - a0, false, dash);
    }

    // Orbiting traveller with a comet tail.
    final angle = t * 2 * math.pi - math.pi / 2;
    for (var i = 8; i >= 0; i--) {
      final a = angle - i * 0.085;
      final pos = c + Offset(math.cos(a), math.sin(a)) * routeR;
      canvas.drawCircle(
        pos,
        5.5 * (1 - i / 10),
        Paint()..color = color.withValues(alpha: 0.75 * (1 - i / 9)),
      );
    }
    final head = c + Offset(math.cos(angle), math.sin(angle)) * routeR;
    canvas.drawCircle(head, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(head, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter old) => old.t != t || old.color != color;
}
