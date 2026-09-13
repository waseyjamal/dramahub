package com.dramahub.drama_hub

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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

        // ── VidSwift channel ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.dramahub.drama_hub/vidswift"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalled" -> {
                    val installed = try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                "com.vidswift.vidswift",
                                PackageManager.PackageInfoFlags.of(0)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo("com.vidswift.vidswift", 0)
                        }
                        true
                    } catch (e: PackageManager.NameNotFoundException) {
                        false
                    }
                    result.success(installed)
                }
                "shareToVidswift" -> {
                    val url = call.argument<String>("url") ?: ""
                    try {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, url)
                            setPackage("com.vidswift.vidswift")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
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