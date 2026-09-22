import 'package:flutter/material.dart';

/// Central colour palette for Rovlo — Blue Theme.
///
/// Light mode: off-white cream surfaces + premium blue buttons/accents.
/// Dark mode:  midnight navy surfaces + vibrant blue buttons/accents.
class AppColors {
  AppColors._();

  // ── Brand / Blue ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2196F3);        // Material Blue 500
  static const Color primaryDark = Color(0xFF1565C0);    // Blue 800
  static const Color primaryLight = Color(0xFF64B5F6);   // Blue 300
  static const Color accent = Color(0xFF2196F3);         // Blue accent
  static const Color secondary = Color(0xFFBBDEFB);      // Blue 100 — soft tint

  // ── Vibrant dark-mode blue ──────────────────────────────────────────────────
  static const Color primaryVibrantDark = Color(0xFF42A5F5); // Blue 400

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const List<Color> brandGradient = [
    Color(0xFF2196F3),
    Color(0xFF1E88E5),
    Color(0xFF1565C0),
  ];

  static const List<Color> blueGradient = [
    Color(0xFF42A5F5),
    Color(0xFF64B5F6),
    Color(0xFF2196F3),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFF1976D2),
    Color(0xFF1565C0),
    Color(0xFF0D47A1),
  ];

  // ── Onboarding header blue ───────────────────────────────────────────────────
  static const Color headerBlue = Color(0xFF2196F3);
  static const Color headerBlueDark = Color(0xFF1976D2);

  // ── Light theme surfaces (warm cream) ────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F8FF); // blue-tinted white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0D1B2A);   // Deep navy-black
  static const Color lightTextSecondary = Color(0xFF607D8B); // Blue-grey

  // ── Onboarding body cream ────────────────────────────────────────────────────
  static const Color creamBackground = Color(0xFFF5F0E8); // warm cream like screenshot
  static const Color creamSurface = Color(0xFFFAF7F0);

  // ── Dark theme surfaces (deep navy) ─────────────────────────────────────────
  static const Color darkBackground = Color(0xFF050C18);  // Very dark navy
  static const Color darkSurface = Color(0xFF0D1B2E);     // Deep navy surface
  static const Color darkCard = Color(0xFF132540);         // Card navy blue
  static const Color darkTextPrimary = Color(0xFFF0F4FF);
  static const Color darkTextSecondary = Color(0xFF78909C);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  static const Color overlayDark = Color(0x99000000);
  static const Color overlayLight = Color(0x33000000);

  // ── High Contrast Elements ──────────────────────────────────────────────────
  static const Color elementBlack = Color(0xFF0D1B2A);  // Deep navy-black
}
