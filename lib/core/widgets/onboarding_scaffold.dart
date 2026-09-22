import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'app_back_button.dart';

import 'rovlo_logo.dart';

/// Shared layout for multi-step profile-setup screens.
///
/// Typography: Uses the editorial Serif font (Newsreader) matching the design mock.
/// Header: Exact SVG geometry with #309AE1 blue wave, SVG linear gradient ellipses,
/// signpost wireline in light grey, and the official Rovlo logo + tagline.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
    this.busy = false,
    this.onBack,
    this.trailing,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onContinue;
  final String continueLabel;
  final bool continueEnabled;
  final bool busy;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progress = step / totalSteps;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBlue =
        isDark ? AppColors.headerBlueDark : const Color(0xFF309AE1);
    final bodyBg =
        isDark ? AppColors.darkBackground : const Color(0xFFFAF8F3);
    final canGoBack = onBack != null || Navigator.canPop(context);
    final backAction = onBack ?? () => Navigator.maybePop(context);

    return Scaffold(
      backgroundColor: bodyBg,
      body: Column(
        children: [
          // ── Exact SVG Wave Header with Ellipses & Signpost ───────────────
          _SvgWaveHeader(
            headerColor: headerBlue,
            isDark: isDark,
            canGoBack: canGoBack,
            onBack: backAction,
          ),

          // ── Cream / White Body ────────────────────────────────────────────
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) =>
                            LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.white12
                              : const Color(0xFFE8E2D6),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(headerBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Step $step of $totalSteps',
                      style: GoogleFonts.newsreader(
                        color: isDark ? Colors.white60 : const Color(0xFF757575),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title — Editorial Serif matching screenshot exactly
                    Text(
                      title,
                      style: GoogleFonts.newsreader(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                        height: 1.18,
                        letterSpacing: -0.2,
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),

                    const SizedBox(height: 8),

                    // Subtitle — Serif body style matching screenshot
                    Text(
                      subtitle,
                      style: GoogleFonts.newsreader(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF555555),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate(delay: 50.ms).fadeIn(duration: 350.ms),

                    const SizedBox(height: 18),

                    // Content area
                    Expanded(
                      child: SingleChildScrollView(child: child)
                          .animate(delay: 90.ms)
                          .fadeIn(duration: 380.ms),
                    ),

                    const SizedBox(height: 12),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (continueEnabled && !busy)
                            ? () {
                                HapticFeedback.lightImpact();
                                onContinue?.call();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: continueEnabled
                              ? const Color(0xFF309AE1)
                              : (isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300),
                          foregroundColor: Colors.white,
                          elevation: continueEnabled ? 1 : 0,
                          shadowColor: const Color(0xFF309AE1).withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                continueLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: continueEnabled
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.grey.shade600),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exact SVG Wave Header painted using SVG path and gradient ellipses
// ─────────────────────────────────────────────────────────────────────────────

class _SvgWaveHeader extends StatelessWidget {
  const _SvgWaveHeader({
    required this.headerColor,
    required this.isDark,
    required this.canGoBack,
    required this.onBack,
  });

  final Color headerColor;
  final bool isDark;
  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final headerHeight = (screenWidth * (288.0 / 360.0)).clamp(230.0, 265.0);

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    // Subtle light grey wireline
    final wireColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : const Color(0xFF64748B).withValues(alpha: 0.35);

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Exact SVG Wave, Ellipses & Signpost Painter ───────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _ExactSvgHeaderPainter(
                headerColor: headerColor,
                wireColor: wireColor,
              ),
            ),
          ),

          // ── Top Bar: Back Button & Rovlo Brand ───────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, left: 18, right: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (canGoBack) ...[
                      RovloBackButton(
                        onPressed: onBack,
                        color: textColor,
                        size: 34,
                        iconSize: 16,
                      ),
                      const SizedBox(width: 10),
                    ],
                    RovloLogo(
                      fontSize: 27,
                      color: textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exact SVG Header Painter (Path + Ellipses + Signpost)
// ─────────────────────────────────────────────────────────────────────────────

class _ExactSvgHeaderPainter extends CustomPainter {
  const _ExactSvgHeaderPainter({
    required this.headerColor,
    required this.wireColor,
  });

  final Color headerColor;
  final Color wireColor;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360.0;
    final sy = size.height / 288.0;

    // ── 1. Main SVG Wave Path ───────────────────────────────────────────────
    final wavePaint = Paint()
      ..color = headerColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0 * sx, -1 * sy);
    path.lineTo(360 * sx, -1 * sy);
    path.lineTo(373.5 * sx, 168 * sy);
    path.lineTo(310.712 * sx, 230.269 * sy);
    path.cubicTo(
      281.699 * sx, 259.042 * sy,
      233.153 * sx, 251.712 * sy,
      213.93 * sx, 215.655 * sy,
    );
    path.lineTo(180.051 * sx, 152.11 * sy);
    path.cubicTo(
      168.248 * sx, 129.971 * sy,
      142.96 * sx, 118.626 * sy,
      118.576 * sx, 124.529 * sy,
    );
    path.lineTo(112.5 * sx, 126 * sy);
    path.lineTo(56 * sx, 144.5 * sy);
    path.lineTo(0 * sx, 162.5 * sy);
    path.close();

    canvas.drawPath(path, wavePaint);

    // ── 2. SVG Gradient Ellipses ────────────────────────────────────────────
    const gradientColors = [
      Color(0xFFDDF2FF), // #DDF2FF
      Color(0xFF64B9F2), // #64B9F2
      Color(0xFF1A80C5), // #1A80C5
    ];
    const gradientStops = [0.0, 0.5, 1.0];

    // (A) Left Ellipse: cx=3, cy=112, rx=24, ry=23
    final rect0 = Rect.fromCenter(
      center: Offset(3 * sx, 112 * sy),
      width: 48 * sx,
      height: 46 * sy,
    );
    final paint0 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.6, -0.6),
        end: Alignment(0.6, 0.6),
        colors: gradientColors,
        stops: gradientStops,
      ).createShader(rect0);
    canvas.drawOval(rect0, paint0);

    // (B) Top-Center Ellipse: cx=187, cy=8.5, rx=27, ry=28.5
    final rect1 = Rect.fromCenter(
      center: Offset(187 * sx, 8.5 * sy),
      width: 54 * sx,
      height: 57 * sy,
    );
    final paint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.4, -0.7),
        end: Alignment(0.4, 0.7),
        colors: gradientColors,
        stops: gradientStops,
      ).createShader(rect1);
    canvas.drawOval(rect1, paint1);

    // (C) Right Ellipse: cx=360.479, cy=143.769, rx=29.7782, ry=38.0525, rotate(23.4938 deg)
    canvas.save();
    canvas.translate(360.479 * sx, 143.769 * sy);
    canvas.rotate(23.4938 * math.pi / 180);
    final rect2 = Rect.fromCenter(
      center: Offset.zero,
      width: 29.7782 * 2 * sx,
      height: 38.0525 * 2 * sy,
    );
    final paint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.4, -0.6),
        end: Alignment(0.5, 0.7),
        colors: gradientColors,
        stops: gradientStops,
      ).createShader(rect2);
    canvas.drawOval(rect2, paint2);
    canvas.restore();

    // ── 3. Signpost and Continuous Wireline (Clipped strictly inside Blue Wave) ──
    canvas.save();
    canvas.clipPath(path);

    final wirePaint = Paint()
      ..color = wireColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lineY = 127 * sy;
    final poleX = 301 * sx;
    final topY = 22 * sy;

    // Continuous horizontal wireline (contained in blue wave)
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), wirePaint);

    // Vertical signpost pole
    canvas.drawLine(Offset(poleX, lineY), Offset(poleX, topY), wirePaint);

    // Sign 1: Top sign pointing LEFT
    final s1Top = topY + 4 * sy;
    final s1Height = 15.0 * sy;
    final s1Width = 32.0 * sx;
    final s1Tip = 7.0 * sx;

    final path1 = Path()
      ..moveTo(poleX, s1Top)
      ..lineTo(poleX - s1Width, s1Top)
      ..lineTo(poleX - s1Width - s1Tip, s1Top + (s1Height / 2))
      ..lineTo(poleX - s1Width, s1Top + s1Height)
      ..lineTo(poleX, s1Top + s1Height)
      ..close();
    canvas.drawPath(path1, wirePaint);

    // Sign 2: Bottom sign pointing RIGHT
    final s2Top = s1Top + s1Height + 6 * sy;
    final s2Height = 15.0 * sy;
    final s2Width = 32.0 * sx;
    final s2Tip = 7.0 * sx;

    final path2 = Path()
      ..moveTo(poleX, s2Top)
      ..lineTo(poleX + s2Width, s2Top)
      ..lineTo(poleX + s2Width + s2Tip, s2Top + (s2Height / 2))
      ..lineTo(poleX + s2Width, s2Top + s2Height)
      ..lineTo(poleX, s2Top + s2Height)
      ..close();
    canvas.drawPath(path2, wirePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ExactSvgHeaderPainter oldDelegate) =>
      oldDelegate.headerColor != headerColor || oldDelegate.wireColor != wireColor;
}
