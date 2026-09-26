import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/verification_service.dart';
import 'face_capture_screen.dart';

/// Get the blue tick with photo verification, in two steps:
///   1. a straight-on selfie with the front camera
///   2. a selfie doing a random pose (proves it is a live person)
/// No ID document is needed. The request goes to the Rovlo admins, who compare
/// the selfies with your profile photos and approve or reject. The photos are
/// private and deleted as soon as the review is done.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  /// A different pose every time, so an old or stolen photo cannot be reused.
  static const List<String> _poses = [
    'Show a thumbs up 👍',
    'Make a peace sign ✌️',
    'Smile and touch your nose 😊',
    'Put your hand on your cheek 🤔',
    'Wave at the camera 👋',
    'Cover one eye with your hand 🙈',
  ];
  final String _challenge = _poses[Random().nextInt(_poses.length)];

  VerificationStatus? _status;
  bool _loadingStatus = true;
  String? _statusError;

  int _step = 0;
  Uint8List? _frontBytes;
  Uint8List? _poseBytes;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _statusError = null;
    });
    try {
      final s = await VerificationService.instance.myStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusError = 'Could not load your verification status. Check your connection.';
        _loadingStatus = false;
      });
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<Uint8List?> _capture({required String title, String? challenge}) {
    return Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FaceCaptureScreen(title: title, challenge: challenge),
      ),
    );
  }

  Future<void> _takeFront() async {
    final bytes = await _capture(title: 'Look straight ahead');
    if (bytes != null && mounted) setState(() => _frontBytes = bytes);
  }

  Future<void> _takePose() async {
    final bytes = await _capture(title: 'Now do the pose', challenge: _challenge);
    if (bytes != null && mounted) setState(() => _poseBytes = bytes);
  }

  Future<void> _submit() async {
    final front = _frontBytes;
    final pose = _poseBytes;
    if (front == null || pose == null) return;
    setState(() => _submitting = true);
    try {
      await VerificationService.instance.submit(
        frontPhoto: front,
        posePhoto: pose,
        challenge: _challenge,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
        // Photos are on the server now — don't keep them in memory.
        _frontBytes = null;
        _poseBytes = null;
      });
    } on VerificationException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    Widget body;
    if (_loadingStatus) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_statusError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_statusError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadStatus, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else if (_submitted || _status?.state == VerificationState.pending) {
      body = _buildSent(primary);
    } else if (_status?.state == VerificationState.approved) {
      body = _buildApproved();
    } else {
      body = _buildSteps(primary, isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Verified'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: body,
    );
  }

  // ── Two steps ───────────────────────────────────────────────────────────────

  Widget _buildSteps(Color primary, bool isDark) {
    final rejected = _status?.state == VerificationState.rejected;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rejected)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Text(
                (_status?.note?.isNotEmpty ?? false)
                    ? 'Your last request was not approved: ${_status!.note}\nPlease try again.'
                    : 'Your last request was not approved. Please try again with clear photos.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          _StepHeader(step: _step, primary: primary),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == 0 ? _buildFrontStep(primary, isDark) : _buildPoseStep(primary, isDark),
          ),
        ],
      ),
    );
  }

  /// A big oval you tap to open the front camera; shows the photo once taken.
  Widget _photoOval({
    required Uint8List? bytes,
    required Color primary,
    required String emptyLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final rovlo = context.rovlo;
    return Center(
      child: GestureDetector(
        onTap: _submitting ? null : onTap,
        child: Container(
          width: 190,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(95, 125)),
            border: Border.all(
              color: bytes != null ? const Color(0xFF22C55E) : primary,
              width: 3,
            ),
            color: rovlo.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: primary)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.92, end: 1.05, duration: 1100.ms),
                    const SizedBox(height: 10),
                    Text(emptyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFrontStep(Color primary, bool isDark) {
    final rovlo = context.rovlo;
    return Column(
      key: const ValueKey('step-front'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Take a straight selfie',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'We open your front camera and guide you. Look straight at the camera in good '
          'light, with no hat or sunglasses, so we can match you to your profile photos.',
          style: TextStyle(color: rovlo.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 22),
        _photoOval(
          bytes: _frontBytes,
          primary: primary,
          emptyLabel: 'Open front camera',
          icon: Icons.face_retouching_natural,
          onTap: _takeFront,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _submitting ? null : _takeFront,
            icon: Icon(_frontBytes == null ? Icons.camera_front : Icons.refresh, size: 18),
            label: Text(_frontBytes == null ? 'Start camera' : 'Retake photo'),
          ),
        ),
        const SizedBox(height: 8),
        const _PrivacyNote(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _frontBytes == null ? null : () => setState(() => _step = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Next: pose photo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildPoseStep(Color primary, bool isDark) {
    final rovlo = context.rovlo;
    return Column(
      key: const ValueKey('step-pose'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Now strike a pose',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'To prove it is really you (and not a saved photo), take one more selfie '
          'doing this pose:',
          style: TextStyle(color: rovlo.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            _challenge,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: primary),
          ),
        ),
        const SizedBox(height: 20),
        _photoOval(
          bytes: _poseBytes,
          primary: primary,
          emptyLabel: 'Open front camera',
          icon: Icons.emoji_emotions_outlined,
          onTap: _takePose,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _submitting ? null : _takePose,
            icon: Icon(_poseBytes == null ? Icons.camera_front : Icons.refresh, size: 18),
            label: Text(_poseBytes == null ? 'Start camera' : 'Retake photo'),
          ),
        ),
        const SizedBox(height: 8),
        const _PrivacyNote(),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(
              onPressed: _submitting ? null : () => setState(() => _step = 0),
              style: OutlinedButton.styleFrom(minimumSize: const Size(90, 54)),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_poseBytes == null || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Submit for verification',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Result screens ──────────────────────────────────────────────────────────

  Widget _buildSent(Color primary) {
    final rovlo = context.rovlo;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 54, color: Color(0xFF22C55E)),
            ).animate().scaleXY(begin: 0.3, end: 1, duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'Sent for verification!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: 10),
            Text(
              'Our team is comparing your selfies with your profile photos. This usually takes '
              '24–48 hours. You will get your blue tick ✓ here as soon as it is approved '
              '— we will let you know either way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: rovlo.textSecondary, height: 1.5),
            ).animate(delay: 300.ms).fadeIn(),
            const SizedBox(height: 24),
            _TimelineRow(icon: Icons.check_circle, label: 'Submitted', done: true, primary: primary),
            _TimelineRow(icon: Icons.hourglass_top_rounded, label: 'Under review', active: true, primary: primary),
            _TimelineRow(icon: Icons.verified_rounded, label: 'Blue tick on your profile', primary: primary),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.maybePop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Back to profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproved() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 88, color: Colors.blue)
                .animate()
                .scaleXY(begin: 0.3, end: 1, duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 18),
            Text('You are verified!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Your profile shows the blue tick.',
                style: TextStyle(color: context.rovlo.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.primary});
  final int step;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    Widget dot(int i, String label) {
      final done = step > i;
      final active = step == i;
      return Expanded(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (done || active) ? primary : Colors.transparent,
                border: Border.all(color: primary, width: 2),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : primary)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? null : context.rovlo.textSecondary)),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dot(0, 'Selfie'),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: 50,
            child: Divider(thickness: 2, color: step > 0 ? primary : primary.withValues(alpha: 0.3)),
          ),
        ),
        dot(1, 'Pose'),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 16, color: context.rovlo.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No ID needed. Your selfies are only used to verify you, stored privately, '
            'visible only to Rovlo admins, and deleted once the review is finished. '
            'They are never shown on your profile.',
            style: TextStyle(fontSize: 12, height: 1.4, color: context.rovlo.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.primary,
    this.done = false,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Color primary;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF22C55E)
        : (active ? primary : context.rovlo.textSecondary.withValues(alpha: 0.5));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontWeight: (done || active) ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}
