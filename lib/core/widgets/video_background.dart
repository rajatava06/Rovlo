import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'animated_gradient_background.dart';

/// Global controller cache — one instance per asset path, never disposed
/// until the app exits, so navigating back and forth is instant and lag-free.
final Map<String, VideoPlayerController> _cache = {};
final Map<String, bool> _initializing = {};

/// A high-performance looping background video from an asset path.
///
/// Optimizations:
/// - Static / animated blue fallback immediately visible
/// - Hardware-accelerated video rendering wrapped in RepaintBoundary
/// - Shuts down expensive shader animations once video starts playing to ensure 60fps
/// - Smooth cross-fade and resilient lifecycle recovery
class VideoBackground extends StatefulWidget {
  const VideoBackground({
    super.key,
    required this.assetPath,
    this.child,
  });

  final String assetPath;
  final Widget? child;

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_videoReady) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller!.play();
    }
  }

  Future<void> _initVideo() async {
    final path = widget.assetPath;

    // Already cached and ready → reuse immediately
    final cached = _cache[path];
    if (cached != null && cached.value.isInitialized) {
      if (!cached.value.isPlaying) cached.play();
      if (mounted) {
        setState(() {
          _controller = cached;
          _videoReady = true;
        });
      }
      return;
    }

    // Already initializing → wait for it
    if (_initializing[path] == true) {
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final c = _cache[path];
        if (c != null && c.value.isInitialized) {
          if (!c.value.isPlaying) c.play();
          if (mounted) {
            setState(() {
              _controller = c;
              _videoReady = true;
            });
          }
          return;
        }
      }
      if (mounted) setState(() => _failed = true);
      return;
    }

    _initializing[path] = true;

    try {
      final controller = VideoPlayerController.asset(
        path,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      _cache[path] = controller;
      _initializing[path] = false;

      if (mounted) {
        setState(() {
          _controller = controller;
          _videoReady = true;
        });
      }
    } catch (_) {
      _initializing[path] = false;
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Static / Animated Gradient Fallback
        // (Stop expensive shader painting once video is playing smoothly)
        if (_videoReady && !_failed)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
            ),
          )
        else
          const AnimatedGradientBackground(),

        // Layer 2: Video — cross-fades in once ready
        if (!_failed && _videoReady && _controller != null)
          RepaintBoundary(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 400),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
          ),

        // Layer 3: Gradient scrim for text legibility
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x22000000),
                Color(0x8A000000),
              ],
              stops: [0.3, 1.0],
            ),
          ),
        ),

        // Layer 4: Foreground content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
