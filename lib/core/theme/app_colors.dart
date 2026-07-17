import 'package:flutter/material.dart';

/// Central colour palette for Rovlo.
///
/// Light mode: pearl-white surfaces + premium dark peach buttons/accents.
/// Dark mode:  midnight navy-blue surfaces + vibrant orange-peach buttons/accents.
class AppColors {
  AppColors._();

  // ── Brand / Peach ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFD46227);       // Rich dark peach (light mode default)
  static const Color primaryDark = Color(0xFFB54F1C);    // Deeper peach
  static const Color primaryLight = Color(0xFFF79E6E);   // Lighter peach
  static const Color accent = Color(0xFFD46227);         // Peach accent
  static const Color secondary = Color(0xFFF9D3BD);      // Soft attractive peach shade

  // ── Vibrant dark-mode peach ────────────────────────────────────────────────
  static const Color primaryVibrantDark = Color(0xFFFF7C32); // Super attractive peach for dark mode

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const List<Color> brandGradient = [
    Color(0xFFD46227),
    Color(0xFFE57A3C),
    Color(0xFFB54F1C),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF7C32),
    Color(0xFFFF9E68),
    Color(0xFFD46227),
  ];

  // ── Light theme surfaces (pearl white) ─────────────────────────────────────
  static const Color lightBackground = Color(0xFFFAF8F5); // warm pearl white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1E140F);  // High contrast near-black warm brown
  static const Color lightTextSecondary = Color(0xFF6B5D55); // Muted brown

  // ── Dark theme surfaces (deeper navy blue) ──────────────────────────────────
  static const Color darkBackground = Color(0xFF040911);  // Midnight space background (very dark)
  static const Color darkSurface = Color(0xFF0D1623);     // Deep slate navy surface
  static const Color darkCard = Color(0xFF142031);         // Card navy blue
  static const Color darkTextPrimary = Color(0xFFF5F6F8);
  static const Color darkTextSecondary = Color(0xFF8FA0B5);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  static const Color overlayDark = Color(0x99000000);
  static const Color overlayLight = Color(0x33000000);

  // ── High Contrast Black Elements ───────────────────────────────────────────
  static const Color elementBlack = Color(0xFF1A1A1A);  // Bold black accents
}
