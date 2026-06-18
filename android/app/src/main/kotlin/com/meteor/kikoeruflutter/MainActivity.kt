package com.meteor.kikoeruflutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import android.view.WindowManager

class MainActivity : AudioServiceActivity() {
    private var floatingLyricPlugin: FloatingLyricPlugin? = null
    private val screenAwakeChannelName = "com.meteor.kikoeruflutter/screen_awake"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册悬浮字幕插件
        floatingLyricPlugin = FloatingLyricPlugin.getInstance(this)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FloatingLyricPlugin.CHANNEL
        )
        floatingLyricPlugin?.attachChannel(channel)
        channel.setMethodCallHandler(floatingLyricPlugin)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenAwakeChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // 不在 Activity 销毁时清理悬浮窗，以便在后台（如侧滑返回桌面）时保持显示
        // floatingLyricPlugin?.cleanup()
        super.onDestroy()
    }
}
