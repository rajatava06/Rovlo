import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'animated_gradient_background.dart';

/// A looping, muted background video that can never make a screen worse.
///
/// Why the previous version lagged / hung on some phones, and what this does
/// about it:
///  * Two decoders stayed alive for the whole session and the covered Welcome
///    video kept playing under the Sign-in page.
///    → one controller per screen, paused while the screen is covered
///      (TickerMode), and disposed with the screen.
///  * `initialize()` could wait forever on some devices/codecs.
///    → hard timeout; on failure the animated gradient stays.
///  * Nothing noticed a video that stalls or drops frames on a weak GPU.
///    → a watchdog checks that playback advances and that frames render in
///      time. If not, the video is dropped for the rest of the session and the
///      cheap gradient is used instead.
///  * The gradient fallback used full-screen blur shaders every frame.
///    → replaced by cheap radial gradients (see AnimatedGradientBackground).
class VideoBackground extends StatefulWidget {
  const VideoBackground({
    super.key,
    required this.assetPath,
    this.child,
  });

  final String assetPath;
  final Widget? child;

  /// Set when a device proved too slow for video; later screens skip it.
  static bool _disabledForSession = false;

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground>
    with WidgetsBindingObserver {
  static const Duration _initTimeout = Duration(seconds: 8);
  static const Duration _measureWindow = Duration(seconds: 3);
  // A frame slower than ~2 vsyncs (at 60 Hz) counts as janky.
  static const int _jankMicros = 34000;

  VideoPlayerController? _controller;
  bool _videoVisible = false;
  bool _coveredByRoute = false;
  bool _disposed = false;

  Timer? _stallTimer;
  Duration _lastPosition = Duration.zero;
  int _stalls = 0;

  TimingsCallback? _timingsCb;
  int _frames = 0;
  int _janky = 0;
  Timer? _measureEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Let the screen paint its first frame (gradient + text) before we spend
    // time on the decoder.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route that is covered by another page gets its tickers disabled.
    final active = TickerMode.of(context);
    final covered = !active;
    if (covered != _coveredByRoute) {
      _coveredByRoute = covered;
      _applyPlayState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyPlayState(background: state != AppLifecycleState.resumed);
  }

  void _applyPlayState({bool background = false}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (background || _coveredByRoute) {
      c.pause();
    } else if (!c.value.isPlaying) {
      c.play();
    }
  }

  Future<void> _start() async {
    if (_disposed || VideoBackground._disabledForSession) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;

    final controller = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    try {
      await controller.initialize().timeout(_initTimeout);
      if (_disposed) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!_coveredByRoute) await controller.play();
    } catch (e) {
      debugPrint('[VideoBackground] falling back to gradient: $e');
      _giveUp(disableForSession: e is TimeoutException);
      return;
    }
    if (_disposed) return;

    controller.addListener(_onControllerUpdate);
    setState(() => _videoVisible = true);
    _startWatchdogs();
  }

  void _onControllerUpdate() {
    if (_controller?.value.hasError ?? false) {
      debugPrint('[VideoBackground] playback error: ${_controller?.value.errorDescription}');
      _giveUp(disableForSession: true);
    }
  }

  // ── Watchdogs ───────────────────────────────────────────────────────────────

  void _startWatchdogs() {
    // 1) Playback must advance while the screen is visible.
    _stallTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final c = _controller;
      if (c == null || !c.value.isInitialized || _coveredByRoute) return;
      if (!c.value.isPlaying) return;
      final pos = c.value.position;
      if (pos == _lastPosition) {
        if (++_stalls >= 2) _giveUp(disableForSession: true);
      } else {
        _stalls = 0;
        _lastPosition = pos;
      }
    });

    // 2) Frames must keep up while the video plays (low-end GPUs).
    _frames = 0;
    _janky = 0;
    _timingsCb = (List<FrameTiming> timings) {
      for (final t in timings) {
        _frames++;
        if (t.totalSpan.inMicroseconds > _jankMicros) _janky++;
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCb!);
    _measureEnd = Timer(_measureWindow, () {
      _removeTimingsCallback();
      // Ignore the very first frames (route transition, shader warm-up).
      if (_frames >= 40 && _janky / _frames > 0.35) {
        debugPrint('[VideoBackground] too slow ($_janky/$_frames janky frames) — using gradient');
        _giveUp(disableForSession: true);
      }
    });
  }

  void _removeTimingsCallback() {
    final cb = _timingsCb;
    if (cb != null) SchedulerBinding.instance.removeTimingsCallback(cb);
    _timingsCb = null;
  }

  void _giveUp({bool disableForSession = false}) {
    if (disableForSession) VideoBackground._disabledForSession = true;
    _stallTimer?.cancel();
    _measureEnd?.cancel();
    _removeTimingsCallback();
    final c = _controller;
    _controller = null;
    if (mounted && !_disposed) setState(() => _videoVisible = false);
    // Dispose after the frame so the VideoPlayer widget is gone first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c?.removeListener(_onControllerUpdate);
      c?.dispose();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stallTimer?.cancel();
    _measureEnd?.cancel();
    _removeTimingsCallback();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo = _videoVisible && controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: gradient — animated until the video is showing, then static
        // (nothing to repaint behind a playing video).
        if (showVideo)
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
          const RepaintBoundary(child: AnimatedGradientBackground()),

        // Layer 2: the video, fading in once it is ready.
        if (showVideo)
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),

        // Layer 3: scrim for text legibility.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0x8A000000)],
              stops: [0.3, 1.0],
            ),
          ),
        ),

        // Layer 4: foreground content.
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
