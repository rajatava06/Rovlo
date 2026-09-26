import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Languages offered by the microphone button.
enum VoiceLang {
  english('English', 'EN', 'en'),
  hindi('हिन्दी', 'हिं', 'hi');

  const VoiceLang(this.label, this.short, this.code);
  final String label;
  final String short;
  final String code;
}

enum VoiceStartResult {
  /// Listening.
  started,

  /// Microphone / speech permission was refused.
  permissionDenied,

  /// This phone has no speech recognition service (or it is switched off).
  unavailable,

  /// The phone has speech recognition but not this language installed.
  languageMissing,

  /// Something else went wrong while starting.
  failed,
}

/// Speech-to-text for the chat composer (English + Hindi).
///
/// Uses the phone's own recognizer (Google on Android, Apple on iOS) — free, no
/// API key. Hindi comes out in Devanagari (हिन्दी).
class VoiceInputService {
  VoiceInputService();

  final SpeechToText _speech = SpeechToText();
  bool _initialised = false;
  List<LocaleName> _locales = const [];

  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  /// Current words (partial while speaking, final at the end).
  final ValueNotifier<String> transcript = ValueNotifier<String>('');

  /// Last error message from the recognizer (empty when none).
  String lastError = '';

  void Function(String finalText)? _onFinal;
  Timer? _fallback;
  DateTime _ignoreStatusUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Future<VoiceStartResult> _init() async {
    if (_initialised) return VoiceStartResult.started;
    try {
      final ok = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
      );
      if (!ok) {
        return await _speech.hasPermission
            ? VoiceStartResult.unavailable
            : VoiceStartResult.permissionDenied;
      }
      _locales = await _speech.locales();
      _initialised = true;
      return VoiceStartResult.started;
    } catch (e) {
      debugPrint('[Voice] init failed: $e');
      return VoiceStartResult.failed;
    }
  }

  /// Finds the best recogniser locale for [lang], or null when the phone lists
  /// its locales and this language is not among them.
  String? _localeFor(VoiceLang lang) {
    if (_locales.isEmpty) {
      // Some phones do not report their locales; try the usual ids anyway.
      return lang == VoiceLang.hindi ? 'hi_IN' : 'en_IN';
    }
    String norm(String id) => id.toLowerCase().replaceAll('-', '_');
    final wanted = lang == VoiceLang.hindi
        ? const ['hi_in']
        : const ['en_in', 'en_us', 'en_gb'];
    for (final w in wanted) {
      for (final l in _locales) {
        if (norm(l.localeId) == w) return l.localeId;
      }
    }
    for (final l in _locales) {
      if (norm(l.localeId).startsWith('${lang.code}_')) return l.localeId;
    }
    return null;
  }

  /// Starts listening. [onFinal] gets the complete text once recognition ends.
  Future<VoiceStartResult> start(
    VoiceLang lang, {
    required void Function(String finalText) onFinal,
  }) async {
    final ready = await _init();
    if (ready != VoiceStartResult.started) return ready;

    final locale = _localeFor(lang);
    if (locale == null) return VoiceStartResult.languageMissing;

    if (_speech.isListening) await _speech.cancel();
    _fallback?.cancel();
    transcript.value = '';
    lastError = '';
    _onFinal = onFinal;
    _delivered = false;
    // Late "done" events from a session that was just cancelled (e.g. when the
    // language is switched) must not end this new one.
    _ignoreStatusUntil = DateTime.now().add(const Duration(milliseconds: 800));

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: locale,
          listenFor: const Duration(seconds: 90),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      listening.value = true;
      return VoiceStartResult.started;
    } catch (e) {
      debugPrint('[Voice] listen failed: $e');
      listening.value = false;
      return VoiceStartResult.failed;
    }
  }

  bool _delivered = false;

  void _onResult(SpeechRecognitionResult r) {
    transcript.value = r.recognizedWords;
    if (r.finalResult) _deliver();
  }

  void _onStatus(String status) {
    if (DateTime.now().isBefore(_ignoreStatusUntil)) return;
    if (status == 'done') {
      listening.value = false;
      _deliver();
    } else if (status == 'notListening') {
      // The recogniser stopped by itself (silence). On Android the final result
      // can still arrive a moment later — wait briefly before giving up.
      listening.value = false;
      _fallback?.cancel();
      _fallback = Timer(const Duration(milliseconds: 1500), _deliver);
    }
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('[Voice] error ${e.errorMsg} permanent=${e.permanent}');
    lastError = e.errorMsg;
    listening.value = false;
    // "no match" / "speech timeout" simply mean nothing was said.
    _deliver();
  }

  void _deliver() {
    _fallback?.cancel();
    if (_delivered) return;
    _delivered = true;
    final cb = _onFinal;
    _onFinal = null;
    cb?.call(transcript.value.trim());
  }

  /// Stops and keeps what was heard.
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    listening.value = false;
    // Some engines never send a final result after stop() — deliver what we have.
    _fallback?.cancel();
    _fallback = Timer(const Duration(milliseconds: 900), _deliver);
  }

  /// Stops and throws away what was heard.
  Future<void> cancel() async {
    _fallback?.cancel();
    _onFinal = null;
    _delivered = true;
    try {
      await _speech.cancel();
    } catch (_) {}
    listening.value = false;
    transcript.value = '';
  }

  Future<void> dispose() async {
    await cancel();
    _fallback?.cancel();
    listening.dispose();
    transcript.dispose();
  }
}
