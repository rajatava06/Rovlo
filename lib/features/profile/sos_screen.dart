import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/sos_service.dart';
import 'emergency_contacts_screen.dart';

/// Full-screen emergency mode: loud siren + vibration, the exact location, and
/// one-tap buttons to call the emergency number and text the emergency contacts.
class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    required this.userName,
    required this.contacts,
  });

  final String userName;
  final List<Map<String, String>> contacts;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with WidgetsBindingObserver {
  final SosService _sos = SosService();
  Timer? _buzz;

  SosSnapshot? _place;
  SosLocationProblem? _problem;
  bool _locating = true;
  bool _muted = false;
  bool _leaving = false;

  late List<String> _numbers;

  @override
  void initState() {
    super.initState();
    _numbers = SosService.cleanNumbers(widget.contacts);
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _sos.startSiren();
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_muted) HapticFeedback.heavyImpact();
    });
    _findLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _buzz?.cancel();
    WakelockPlus.disable();
    unawaited(_sos.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the dialler / SMS app: the siren carries on.
    if (state == AppLifecycleState.resumed && !_muted && !_sos.playing && !_leaving) {
      _sos.startSiren();
    }
  }

  Future<void> _findLocation() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    final res = await _sos.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _place = res.snapshot;
      _problem = res.problem;
    });
  }

  String get _message => SosService.buildMessage(name: widget.userName, location: _place);

  String get _emergencyNumber => SosService.emergencyNumber(_place?.countryCode);

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _open(Uri uri, String failMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    // Free the audio channel while the call / SMS app is in front.
    await _sos.pauseSiren();
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(failMessage)));
      if (!_muted) unawaited(_sos.startSiren());
    }
  }

  void _call() => _open(
        Uri(scheme: 'tel', path: _emergencyNumber),
        'Could not open the phone app. Dial $_emergencyNumber manually.',
      );

  void _textContacts() {
    if (_numbers.isEmpty) return;
    _open(
      SosService.smsUri(_numbers, _message, ios: defaultTargetPlatform == TargetPlatform.iOS),
      'Could not open the messages app. Use "Share location" instead.',
    );
  }

  Future<void> _share() async {
    await Share.share(_message, subject: 'Emergency — my location');
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    if (_muted) {
      await _sos.pauseSiren();
    } else {
      await _sos.startSiren();
    }
  }

  Future<void> _addContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
    );
    if (!mounted) return;
    // Pick up the numbers that were just added.
    final fresh = context.read<AuthProvider>().currentUser?.emergencyContacts ?? const [];
    setState(() => _numbers = SosService.cleanNumbers(fresh));
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the SOS?'),
        content: const Text('Only stop if you are safe. The alarm will end.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep SOS on')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("I'm safe — stop")),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _leaving = true;
    await _sos.stopSiren();
    if (mounted) Navigator.pop(context);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB71C1C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 0.9, end: 1.15, duration: 500.ms),
                const SizedBox(height: 6),
                const Text(
                  'SOS ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _muted ? 'Siren muted' : 'Loud alarm is playing',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                _locationCard(),
                const Spacer(),
                _bigButton(
                  icon: Icons.call,
                  label: 'Call $_emergencyNumber (emergency)',
                  onTap: _call,
                  primary: true,
                ),
                const SizedBox(height: 10),
                if (_numbers.isNotEmpty)
                  _bigButton(
                    icon: Icons.sms,
                    label: 'Text my location to ${_numbers.length} contact${_numbers.length == 1 ? '' : 's'}',
                    onTap: _textContacts,
                  )
                else
                  _bigButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Add emergency contacts',
                    onTap: _addContacts,
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _smallButton(
                        icon: Icons.share_location,
                        label: 'Share location',
                        onTap: _share,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _smallButton(
                        icon: _muted ? Icons.volume_up : Icons.volume_off,
                        label: _muted ? 'Siren on' : 'Mute siren',
                        onTap: _toggleMute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _stop,
                  child: const Text(
                    "I'm safe — stop SOS",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationCard() {
    final place = _place;
    Widget content;
    if (_locating) {
      content = const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text('Getting your exact location…',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    } else if (place != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Your location is ready',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          if (place.address.isNotEmpty)
            Text(place.address, style: const TextStyle(color: Colors.white, height: 1.35)),
          Text(
            '${place.lat.toStringAsFixed(5)}, ${place.lng.toStringAsFixed(5)}'
            '${place.accuracyMeters != null ? '  ·  ±${place.accuracyMeters!.round()} m' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      );
    } else {
      final text = switch (_problem) {
        SosLocationProblem.serviceOff => 'Location (GPS) is turned off. Turn it on so we can share where you are.',
        SosLocationProblem.denied || SosLocationProblem.deniedForever =>
          'Location permission is blocked. Allow it in Settings to share where you are.',
        _ => 'Could not get your location. You can still call for help.',
      };
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              TextButton(onPressed: _findLocation, child: const Text('Try again')),
              if (_problem == SosLocationProblem.deniedForever ||
                  _problem == SosLocationProblem.serviceOff)
                TextButton(
                  onPressed: () => _problem == SosLocationProblem.serviceOff
                      ? Geolocator.openLocationSettings()
                      : Geolocator.openAppSettings(),
                  child: const Text('Open settings'),
                ),
            ],
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: primary ? Colors.white : Colors.black.withValues(alpha: 0.35),
        foregroundColor: primary ? const Color(0xFFB71C1C) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
