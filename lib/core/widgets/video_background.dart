import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'animated_gradient_background.dart';

/// Cache for initialized video controllers so video background plays instantly
/// across screen transitions without reloading or delay.
final Map<String, VideoPlayerController> _cachedControllers = {};
final Map<String, Future<void>> _initFutures = {};

/// Plays a looping, muted background video from an asset with zero-delay playback
/// and smooth gradient fallback transition.
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
    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = widget.assetPath;

    // Check if we already have a cached and initialized controller
    if (_cachedControllers.containsKey(path)) {
      final cached = _cachedControllers[path]!;
      if (cached.value.isInitialized) {
        if (!cached.value.isPlaying) {
          cached.play();
        }
        if (mounted) {
          setState(() {
            _controller = cached;
            _ready = true;
          });
        }
        return;
      }
    }

    try {
      // Direct native video player initialization (skips rootBundle.load RAM bottleneck)
      final controller = VideoPlayerController.asset(path);

      _initFutures[path] ??= controller.initialize();
      await _initFutures[path];

      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      _cachedControllers[path] = controller;

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Always render animated gradient underneath as instant background
        AnimatedGradientBackground(),

        // Cross-fade to video player as soon as controller is initialized
        if (!_failed && _ready && _controller != null && _controller!.value.isInitialized)
          AnimatedOpacity(
            opacity: _ready ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

        // Dark scrim overlay for high text legibility
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0xB3000000)],
            ),
          ),
        ),

        // Foreground contents
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
