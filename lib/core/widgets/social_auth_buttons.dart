import 'package:flutter/material.dart';

/// Google / Apple sign-in buttons with brand-correct styling.
///
/// Icons are drawn with CustomPaint / Unicode so no image assets are needed.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background,
    this.foreground,
    this.border,
    this.loading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final Color? border;
  final bool loading;

  factory SocialButton.google({
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SocialButton(
      label: 'Continue with Google',
      icon: const _GoogleG(),
      onPressed: onPressed,
      loading: loading,
      background: Colors.white,
      foreground: const Color(0xFF1F1F1F),
      border: const Color(0xFFDADCE0),
    );
  }

  factory SocialButton.apple({
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SocialButton(
      label: 'Continue with Apple',
      icon: const Text(
        '', // Apple logo glyph on Apple platforms; falls back gracefully.
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
      onPressed: onPressed,
      loading: loading,
      background: Colors.black,
      foreground: Colors.white,
      border: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.white;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border ?? Colors.transparent),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: Center(child: icon)),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A small, recognisable multi-colour Google "G" drawn without assets.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final stroke = size.width * 0.22;

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final r = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    // Blue, green, yellow, red quarters approximating the Google G.
    canvas.drawArc(r, -0.5, 1.3, false, arc(const Color(0xFF4285F4)));
    canvas.drawArc(r, 0.9, 1.4, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(r, 2.4, 1.3, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(r, 3.8, 1.5, false, arc(const Color(0xFFEA4335)));

    // Horizontal bar of the G.
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - stroke / 2, radius, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
