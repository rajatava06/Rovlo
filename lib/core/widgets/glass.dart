import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Clear 3D glass, meant to sit on top of photos.
///
/// Layers (bottom to top): frosted blur of the photo behind → a very faint
/// white tint → a glossy highlight on the upper half → a thin light rim that is
/// bright top-left and fades out (a light source) → a soft shadow underneath.
/// It has no colour of its own, so it suits every image.
class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.borderRadius,
    required this.child,
    this.glossHeight = 13,
  });

  final double borderRadius;
  final Widget child;
  final double glossHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Rim: a gradient "border" made by a 1.2px gap around the glass body.
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.20),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 9,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Stack(
            children: [
              // Faint clear tint
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
              // Gloss on the upper half
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: glossHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Thin lower inner glow (glass thickness)
              Positioned(
                left: 6,
                right: 6,
                bottom: 0,
                height: 1.1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A small label pill made of clear glass.
class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.label,
    this.dotColor,
    this.icon,
    this.iconColor = Colors.white,
    this.fontSize = 10.5,
    this.horizontalPadding = 12,
    this.verticalPadding = 6,
  });

  final String label;

  /// Optional small coloured dot before the text (e.g. the event's accent).
  final Color? dotColor;

  /// Optional icon before the text (e.g. a star for ratings).
  final IconData? icon;
  final Color iconColor;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      borderRadius: 15,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: dotColor!.withValues(alpha: 0.7), blurRadius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: fontSize + 3, color: iconColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0.5,
                  shadows: const [
                    Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon button made of clear glass (back / save / share on photos).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.white,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: _GlassShell(
            borderRadius: size / 2,
            glossHeight: size * 0.42,
            child: Center(
              child: Icon(
                icon,
                size: size * 0.48,
                color: iconColor,
                shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
