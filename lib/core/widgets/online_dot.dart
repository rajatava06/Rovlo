import 'package:flutter/material.dart';

import '../../services/presence_service.dart';

/// The green "online now" dot, driven live by [PresenceService].
/// Shows nothing while the person is offline.
class OnlineDot extends StatelessWidget {
  const OnlineDot({
    super.key,
    required this.userId,
    this.size = 12,
    this.borderColor,
    this.borderWidth = 2,
  });

  final String userId;
  final double size;

  /// Ring that separates the dot from the avatar (usually the card colour).
  final Color? borderColor;
  final double borderWidth;

  static const Color green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: PresenceService.instance.online,
      builder: (context, online, _) {
        if (!online.contains(userId)) return const SizedBox.shrink();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: green,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? Theme.of(context).scaffoldBackgroundColor,
              width: borderWidth,
            ),
          ),
        );
      },
    );
  }
}

/// True while [userId] is online (rebuilds when it changes).
class OnlineBuilder extends StatelessWidget {
  const OnlineBuilder({super.key, required this.userId, required this.builder});

  final String userId;
  final Widget Function(BuildContext context, bool online) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: PresenceService.instance.online,
      builder: (context, online, _) => builder(context, online.contains(userId)),
    );
  }
}
