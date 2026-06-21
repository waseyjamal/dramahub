package com.dramahub.drama_hub

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dramahub.drama_hub/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Security channel (untouched) ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureMode" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecureMode" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Brightness channel (new) ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.dramahub.drama_hub/brightness"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    val brightness = call.argument<Double>("brightness")?.toFloat() ?: -1f
                    runOnUiThread {
                        val lp = window.attributes
                        lp.screenBrightness = brightness.coerceIn(0.01f, 1.0f)
                        window.attributes = lp
                    }
                    result.success(null)
                }
                "resetBrightness" -> {
                    runOnUiThread {
                        val lp = window.attributes
                        lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp
                    }
                    result.success(null)
                }
                "getBrightness" -> {
                    val brightness = window.attributes.screenBrightness
                    result.success(brightness.toDouble())
                }
                else -> result.notImplemented()
            }
        }
    }
}