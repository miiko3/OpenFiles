package com.openfiles.openfiles

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var saf: SafBridge? = null
    private var inbox: Inbox? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        saf = SafBridge(this).also { it.attach(messenger) }
        inbox = Inbox(this).also { it.attach(messenger) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        inbox?.ingest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        inbox?.ingest(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (saf?.onActivityResult(requestCode, resultCode, data) == true) return
        inbox?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        saf?.onRequestPermissionsResult(requestCode, grantResults)
    }

    companion object {
        const val REQ_TREE = 0x5AFE
        const val REQ_OPEN = 0x5AF0
        const val REQ_PERMS = 0x5A11
    }
}