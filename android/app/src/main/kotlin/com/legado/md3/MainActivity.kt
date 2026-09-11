package com.legado.md3

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channelName = "legado/file_intent"
    private var pendingPath: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingPath = resolveIntent(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                val p = pendingPath
                pendingPath = null
                result.success(p)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val p = resolveIntent(intent)
        if (p != null) {
            pendingPath = p
            channel?.invokeMethod("onFileOpened", p)
        }
    }

    private fun resolveIntent(intent: Intent?): String? {
        val uri: Uri = intent?.data ?: return null
        return try {
            when (uri.scheme) {
                "file" -> uri.path
                "content" -> {
                    val name = uri.lastPathSegment ?: "opened_${System.currentTimeMillis()}"
                    val out = File(cacheDir, sanitize(name))
                    contentResolver.openInputStream(uri)?.use { input ->
                        out.outputStream().use { o -> input.copyTo(o) }
                    }
                    out.absolutePath
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun sanitize(name: String): String {
        val base = name.substringAfterLast('/')
        return if (base.contains('.')) base else "$base.txt"
    }
}
