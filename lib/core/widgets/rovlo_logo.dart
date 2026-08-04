import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The Rovlo brand logo. Shows the "R" icon mark alongside the "Rovlo."
/// wordmark. Optionally rendered with a gradient shader (used over the
/// video/gradient hero) or a solid colour (used in app bars).
class RovloLogo extends StatelessWidget {
  const RovloLogo({
    super.key,
    this.fontSize = 56,
    this.gradient = true,
    this.color,
    this.showDot = true,
    this.showIcon = true,
  });

  final double fontSize;
  final bool gradient;
  final Color? color;
  final bool showDot;
  final bool showIcon;

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

    final logoRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          Container(
            padding: EdgeInsets.all(fontSize * 0.08),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(fontSize * 0.25),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(fontSize * 0.22),
              child: Image.asset(
                'assets/images/rovlo_logo.jpg',
                width: fontSize * 1.5,
                height: fontSize * 1.5,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: fontSize * 0.22),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: text,
          ),
        ),
      ],
    );

    if (!gradient) return logoRow;

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFFCFF7F2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: logoRow,
    );
  }
}
