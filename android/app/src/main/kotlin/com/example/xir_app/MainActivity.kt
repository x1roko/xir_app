package com.example.xir_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.xir_app/process_text"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "processText") {
                val sharedText = intent?.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
                if (sharedText != null) {
                    result.success(sharedText)
                } else {
                    result.error("", "", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
