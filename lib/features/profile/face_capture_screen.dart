import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';

enum _Phase { starting, ready, countdown, captured, error }

/// Opens the FRONT camera inside the app, guides the user to centre their face
/// in an animated oval, counts down 3-2-1 and takes the photo.
///
/// Pops with the JPEG bytes, or null if the user backs out.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    this.title = 'Take a face photo',
    this.challenge,
  });

  /// Heading while the camera is ready.
  final String title;

  /// A pose the person must do in the photo (e.g. "Show a thumbs up 👍").
  final String? challenge;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _Phase _phase = _Phase.starting;
  String _error = '';
  bool _permissionProblem = false;
  int _count = 3;
  Timer? _timer;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _timer?.cancel();
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed &&
        _phase != _Phase.captured &&
        _phase != _Phase.error) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    setState(() => _phase = _Phase.starting);
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw CameraException('noFront', 'No front camera'),
      );
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _phase = _Phase.ready);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _permissionProblem = e.code.contains('Denied') || e.code.contains('Restricted');
        _error = switch (e.code) {
          'noFront' => 'This phone has no front camera.',
          _ when _permissionProblem =>
            'Camera access is blocked. Allow it in Settings to take your photo.',
          _ => 'Could not open the camera. Please try again.',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Could not open the camera. Please try again.';
      });
    }
  }

  void _begin() {
    if (_phase != _Phase.ready) return;
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.countdown;
      _count = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_count > 1) {
        HapticFeedback.selectionClick();
        setState(() => _count--);
        return;
      }
      t.cancel();
      await _capture();
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      // Don't leave the photo lying around in the cache.
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _phase = _Phase.captured;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Could not take the photo. Please try again.';
      });
    }
  }

  void _retake() {
    setState(() {
      _photo = null;
      _phase = _Phase.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ovalW = (width * 0.74).clamp(220.0, 320.0);
    final ovalH = ovalW * 1.32;

    final title = switch (_phase) {
      _Phase.captured => 'Looking good!',
      _Phase.countdown => 'Hold still…',
      _Phase.error => 'Camera problem',
      _ => widget.title,
    };
    final hint = switch (_phase) {
      _Phase.starting => 'Opening the front camera…',
      _Phase.ready => widget.challenge != null
          ? 'Centre your face in the oval and do the pose below. Good light, no hat or sunglasses.'
          : 'Centre your face in the oval, in good light, without a hat or sunglasses.',
      _Phase.countdown => 'Look straight at the camera',
      _Phase.captured => 'Make sure your whole face is clear and visible.',
      _Phase.error => _error,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ).animate(key: ValueKey(title)).fadeIn(duration: 250.ms),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
            ),
            if (widget.challenge != null && _phase != _Phase.error) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFFFC107), width: 1.4),
                ),
                child: Text(
                  widget.challenge!,
                  style: const TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                    begin: 1,
                    end: 1.05,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
            ],
            const Spacer(),
            SizedBox(
              width: ovalW + 24,
              height: ovalH + 24,
              child: _buildOval(ovalW, ovalH),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: _buildActions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOval(double w, double h) {
    final scanning = _phase == _Phase.ready || _phase == _Phase.countdown;
    final done = _phase == _Phase.captured;
    final ringColor = done
        ? const Color(0xFF22C55E)
        : (_phase == _Phase.countdown ? const Color(0xFFFFC107) : AppColors.primary);

    Widget content;
    if (_photo != null) {
      content = Image.memory(_photo!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (_controller != null && _controller!.value.isInitialized) {
      final size = _controller!.value.previewSize!;
      // The sensor reports landscape sizes; the phone is held in portrait.
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(_controller!),
        ),
      );
    } else {
      content = Center(
        child: _phase == _Phase.error
            ? const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 56)
            : const CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing glow while waiting.
        Container(
          width: w + 24,
          height: h + 24,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.elliptical((w + 24) / 2, (h + 24) / 2)),
            boxShadow: [
              BoxShadow(color: ringColor.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: 2),
            ],
          ),
        )
            .animate(
              key: ValueKey('glow-$_phase'),
              onPlay: (c) => scanning ? c.repeat(reverse: true) : c.stop(),
            )
            .scaleXY(begin: 0.97, end: 1.02, duration: 900.ms, curve: Curves.easeInOut),

        ClipOval(
          child: SizedBox(width: w, height: h, child: ColoredBox(color: Colors.black, child: content)),
        ),

        // Scan line sweeping over the face.
        if (scanning)
          ClipOval(
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          ringColor,
                          Colors.transparent,
                        ]),
                        boxShadow: [
                          BoxShadow(color: ringColor.withValues(alpha: 0.8), blurRadius: 12),
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: 0, end: h - 3, duration: 1600.ms, curve: Curves.easeInOut),
                  ),
                ],
              ),
            ),
          ),

        // The oval outline.
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
            border: Border.all(color: ringColor, width: 3.5),
          ),
        ),

        // 3 · 2 · 1
        if (_phase == _Phase.countdown)
          Text(
            '$_count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 96,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
            ),
          )
              .animate(key: ValueKey(_count))
              .scaleXY(begin: 1.6, end: 1, duration: 500.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 200.ms),

        // Success tick.
        if (done)
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
            ).animate().scaleXY(begin: 0, end: 1, duration: 450.ms, curve: Curves.elasticOut),
          ),
      ],
    );
  }

  Widget _buildActions() {
    switch (_phase) {
      case _Phase.captured:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _retake,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _photo),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text(
                  'Use this photo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      case _Phase.error:
        return Column(
          children: [
            ElevatedButton(
              onPressed: _permissionProblem ? Geolocator.openAppSettings : _startCamera,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _permissionProblem ? 'Open Settings' : 'Try again',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (_permissionProblem)
              TextButton(onPressed: _startCamera, child: const Text('I allowed it — retry')),
          ],
        );
      default:
        final ready = _phase == _Phase.ready;
        return ElevatedButton.icon(
          onPressed: ready ? _begin : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.white12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
          label: Text(
            _phase == _Phase.countdown ? 'Capturing…' : 'Start',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
    }
  }
}
