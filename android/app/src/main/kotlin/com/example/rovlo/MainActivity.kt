package com.example.rovlo

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SOS siren: play on the ALARM stream at full volume (works even when the
        // ringer is on silent), then put the user's volume back afterwards.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rovlo/sos")
            .setMethodCallHandler { call, result ->
                val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "maxAlarmVolume" -> {
                        val previous = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                        try {
                            audio.setStreamVolume(
                                AudioManager.STREAM_ALARM,
                                audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                                0
                            )
                        } catch (e: SecurityException) {
                            // Do-not-disturb policy blocks changing it: play at the current level.
                        }
                        result.success(previous)
                    }
                    "restoreAlarmVolume" -> {
                        val level = call.argument<Int>("level")
                        if (level != null) {
                            try {
                                audio.setStreamVolume(AudioManager.STREAM_ALARM, level, 0)
                            } catch (e: SecurityException) {
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
