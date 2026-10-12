package com.openfiles.openfiles

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class Inbox(private val activity: Activity) {

    companion object {
        private const val CHANNEL = "com.openfiles/inbox"
    }

    private lateinit var channel: MethodChannel
    private var pendingResult: MethodChannel.Result? = null

    private fun resolver() = activity.contentResolver

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "take" -> {
                    pendingResult = result
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun ingest(intent: Intent?) {
        val list = extract(intent) ?: return
        channel.invokeMethod("onFiles", list)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != MainActivity.REQ_OPEN || pendingResult == null) return false
        val result = pendingResult!!
        pendingResult = null
        result.success(true)
        return false
    }

    private fun extract(intent: Intent?): List<Map<String, Any?>>? {
        if (intent == null) return null
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    ?.let { uris.addAll(it) }
            }
            Intent.ACTION_PROCESS_TEXT -> intent.data?.let { uris.add(it) }
            else -> return null
        }
        if (uris.isEmpty()) return null
        for (uri in uris) {
            try {
                activity.grantUriPermission(
                    activity.packageName,
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
        }
        return uris.map { describe(it) }
    }

    private fun describe(uri: Uri): Map<String, Any?> {
        var name = uri.lastPathSegment ?: "file"
        var size = -1L
        resolver().query(uri, null, null, null, null)?.use { c ->
            val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val si = c.getColumnIndex(OpenableColumns.SIZE)
            if (c.moveToFirst()) {
                if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni)
                if (si >= 0 && !c.isNull(si)) size = c.getLong(si)
            }
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to name,
            "mime" to (resolver().getType(uri) ?: "application/octet-stream"),
            "size" to size,
            "canWrite" to false
        )
    }
}