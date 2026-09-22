import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Global unified `<` back button used across all screens.
///
/// Provides:
/// - Distinct `<` iOS chevron icon
/// - Haptic feedback on tap
/// - Subtle circular glass container
class RovloBackButton extends StatelessWidget {
  const RovloBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 38,
    this.iconSize = 18,
  });

  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.07);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.maybePop(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? defaultBg,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 1.5), // visually center iOS chevron
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
