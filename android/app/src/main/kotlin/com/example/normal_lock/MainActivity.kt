package com.example.snooze_fest

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "alarm_foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val args = call.arguments as? Map<*, *>
                    val intent = Intent(this, AlarmForegroundService::class.java)
                    if (args != null) {
                        (args["vibrate"] as? Boolean)?.let { intent.putExtra("vibrate", it) }
                        (args["audioPath"] as? String)?.let { intent.putExtra("audioPath", it) }
                        (args["alarmId"] as? Int)?.let { intent.putExtra("alarmId", it) }
                    }
                    startForegroundService(intent)
                    result.success(null)
                }
                "stopService" -> {
                    val intent = Intent(this, AlarmForegroundService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
