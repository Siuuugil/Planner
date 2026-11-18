package com.siuuugil.game_planner

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 다른 앱에서 "공유 → 마이플래너"로 보낸 글·링크를 Flutter 쪽(📥 수집)에 넘긴다.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var shared: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shared = sharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myplanner/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeShared") {
                    result.success(shared)
                    shared = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedText(intent) ?: return
        setIntent(intent)
        shared = text
        channel?.invokeMethod("shared", null)
    }

    private fun sharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()
        val joined = when {
            subject.isEmpty() || text.contains(subject) -> text
            text.isEmpty() -> subject
            else -> "$subject\n$text"
        }
        // 같은 공유가 두 번 처리되지 않게 (화면 회전·재생성 등)
        intent.action = Intent.ACTION_MAIN
        return joined.ifEmpty { null }
    }
}
