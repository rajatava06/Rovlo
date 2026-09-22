import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The official Rovlo brand logo.
/// Combines the custom 'R' icon mark (with the walking traveler silhouette cutout)
/// and the bold 'ovlo' wordmark, with optional subtitle/tagline support.
class RovloLogo extends StatelessWidget {
  const RovloLogo({
    super.key,
    this.fontSize = 28,
    this.gradient = false,
    this.color,
    this.showDot = false,
    this.showIcon = true,
    this.tagline,
  });

  final double fontSize;
  final bool gradient;
  final Color? color;
  final bool showDot;
  final bool showIcon;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    final textStyle = GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: effectiveColor,
      height: 1.0,
    );

    final logoRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          Image.asset(
            'assets/images/rovlo_icon.png',
            height: fontSize * 0.92,
            width: fontSize * 0.92 * (418 / 496),
            fit: BoxFit.contain,
            color: effectiveColor,
          ),
          SizedBox(width: fontSize * 0.04),
        ],
        Text('ovlo', style: textStyle),
        if (showDot)
          Text('.', style: textStyle.copyWith(color: AppColors.primary)),
      ],
    );

    Widget content = logoRow;
    if (gradient) {
      content = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Color(0xFFCFF7F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: logoRow,
      );
    }

    if (tagline != null && tagline!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 3),
          Text(
            tagline!,
            style: GoogleFonts.poppins(
              fontSize: (fontSize * 0.44).clamp(11.0, 16.0),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
              color: effectiveColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    }

    return content;
  }
}
