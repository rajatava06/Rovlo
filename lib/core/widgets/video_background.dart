import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'animated_gradient_background.dart';

/// Plays a looping, muted background video from an asset.
///
/// If the asset is missing or fails to load, it silently falls back to the
/// [AnimatedGradientBackground] so the Welcome screen always looks polished.
class VideoBackground extends StatefulWidget {
  const VideoBackground({super.key, required this.assetPath, this.child});

  final String assetPath;
  final Widget? child;

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Confirm the asset actually exists before spinning up the player;
      // rootBundle throws if it's absent, which we treat as "use fallback".
      await rootBundle.load(widget.assetPath);
      final controller = VideoPlayerController.asset(widget.assetPath);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (!_ready && _controller == null)) {
      // Fallback (or brief loading window): animated gradient.
      return AnimatedGradientBackground(child: widget.child);
    }

    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        // Dark scrim so foreground text stays legible over any footage.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0xB3000000)],
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
