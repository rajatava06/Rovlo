import 'package:flutter/material.dart';

/// Central colour palette for Rovlo.
///
/// Keeping every colour here guarantees a single, constant theme across the
/// whole app. Screens should never hard-code colours — always reference these.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1FB6A6); // teal / travel green-blue
  static const Color primaryDark = Color(0xFF0E8C80);
  static const Color accent = Color(0xFFFFB74D); // warm sunset amber
  static const Color secondary = Color(0xFF3A6EA5); // deep sky blue

  // Gradients used behind the welcome video / hero areas.
  static const List<Color> brandGradient = [
    Color(0xFF0E8C80),
    Color(0xFF1FB6A6),
    Color(0xFF3A6EA5),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF8A65),
    Color(0xFFFFB74D),
    Color(0xFF7E57C2),
  ];

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF10202B);
  static const Color lightTextSecondary = Color(0xFF5B6B78);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0B1418);
  static const Color darkSurface = Color(0xFF12222A);
  static const Color darkCard = Color(0xFF172A33);
  static const Color darkTextPrimary = Color(0xFFF2F6F8);
  static const Color darkTextSecondary = Color(0xFF9FB2BC);

  // Semantic
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  static const Color overlayDark = Color(0x99000000);
  static const Color overlayLight = Color(0x33000000);
}
