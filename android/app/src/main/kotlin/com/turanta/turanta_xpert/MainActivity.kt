package com.turanta.turanta_xpert

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes `Settings.Secure.ANDROID_ID` to Dart.
 *
 * The partner app binds an account to one phone, and the id it bound with used
 * to be a UUID in SharedPreferences — which Android deletes on uninstall. A
 * partner who reinstalled came back looking like a stranger on a new handset
 * and had to ask an admin to clear their device before they could log in.
 *
 * ANDROID_ID survives reinstall and only changes on a factory reset, which is
 * the behaviour that binding actually wanted.
 */
class MainActivity : FlutterActivity() {
    private val channel = "com.turanta.turanta_xpert/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    result.success(androidId())
                } else {
                    result.notImplemented()
                }
            }
    }

    @SuppressLint("HardwareIds")
    private fun androidId(): String? =
        try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        } catch (e: Exception) {
            null
        }
}
