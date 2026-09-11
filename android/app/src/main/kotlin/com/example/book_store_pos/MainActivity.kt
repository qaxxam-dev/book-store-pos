package com.example.book_store_pos

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.media.AudioAttributes
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.app/force_vibrate"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "forceVibrate") {
                forceVibrate()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun forceVibrate() {
        val duration = 50L // 50ms is short and crisp
        val amplitude = 255 // Max power

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            val vibrator = vibratorManager.defaultVibrator
            triggerVibration(vibrator, duration, amplitude)
        } else {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            triggerVibration(vibrator, duration, amplitude)
        }
    }

    private fun triggerVibration(vibrator: Vibrator, duration: Long, amplitude: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // THE TRICK: Set usage to USAGE_ALARM to bypass system "Touch Vibration" off settings
            val vibrationAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM) 
                .build()

            val effect = VibrationEffect.createOneShot(duration, amplitude)
            vibrator.vibrate(effect, vibrationAttributes)
        } else {
            vibrator.vibrate(duration)
        }
    }
}
