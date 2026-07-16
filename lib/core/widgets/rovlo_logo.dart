import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The "Rovlo" wordmark. Optionally rendered with a gradient shader (used over
/// the video/gradient hero) or a solid colour (used in app bars).
class RovloLogo extends StatelessWidget {
  const RovloLogo({
    super.key,
    this.fontSize = 56,
    this.gradient = true,
    this.color,
    this.showDot = true,
  });

  final double fontSize;
  final bool gradient;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: color ?? Colors.white,
    );

    final text = RichText(
      text: TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Rovlo'),
          if (showDot)
            TextSpan(
              text: '.',
              style: style.copyWith(color: AppColors.accent),
            ),
        ],
      ),
    );

    if (!gradient) return text;

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFFCFF7F2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: text,
    );
  }
}
