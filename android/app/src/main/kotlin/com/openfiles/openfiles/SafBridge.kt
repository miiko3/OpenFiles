package com.openfiles.openfiles

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SafBridge(private val activity: Activity) {

    companion object {
        private const val CHANNEL = "com.openfiles/saf"
    }

    private lateinit var channel: MethodChannel
    private var pending: MethodChannel.Result? = null

    private val resolver get() = activity.contentResolver

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickTree" -> pickTree(result)
                "pickFiles" -> pickFiles(call, result)
                "persistPermission" -> result.success(persist(call))
                "releasePermission" -> result.success(release(call))
                "listChildren" -> result.success(listChildren(call))
                "stat" -> result.success(stat(call))
                "readToCache" -> result.success(readToCache(call))
                "readBytes" -> result.success(readBytes(call))
                "writeFromPath" -> result.success(writeFromPath(call))
                "writeBytes" -> result.success(writeBytes(call))
                "createFile" -> result.success(createFile(call))
                "createDir" -> result.success(createDir(call))
                "delete" -> result.success(deleteEntry(call))
                "rename" -> result.success(rename(call))
                "move" -> result.success(move(call))
                "copy" -> result.success(copy(call))
                "hasPermission" -> result.success(hasPersistable(call))
                "shareFile" -> result.success(shareFile(call))
                "appDirs" -> result.success(appDirs())
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        } catch (e: Exception) {
            result.error("io", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun tree(call: MethodCall): Uri = Uri.parse(call.argument<String>("treeUri")!!)

    private fun doc(call: MethodCall): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree(call), call.argument<String>("docId")!!)

    private fun docId(call: MethodCall): String = call.argument<String>("docId")!!

    private fun pickTree(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        startForResult(intent, MainActivity.REQ_TREE, result, false)
    }

    private fun pickFiles(call: MethodCall, result: MethodChannel.Result) {
        val multiple = call.argument<Boolean>("multiple") ?: false
        val mime = call.argument<String>("mime")
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
            type = if (mime.isNullOrBlank()) "*/*" else mime
        }
        startForResult(intent, MainActivity.REQ_OPEN, result, multiple)
    }

    private fun startForResult(
        intent: Intent,
        request: Int,
        result: MethodChannel.Result,
        multiple: Boolean
    ) {
        if (pending != null) {
            result.error("busy", "Another picker is already open", null)
            return
        }
        pending = result
        activity.startActivityForResult(
            if (multiple) Intent.createChooser(intent, null) else intent,
            request
        )
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != MainActivity.REQ_TREE && requestCode != MainActivity.REQ_OPEN) return false
        val result = pending ?: return true
        pending = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }

        takePersistable(data)
        if (requestCode == MainActivity.REQ_TREE) {
            val uri = data.data
            if (uri == null) {
                result.success(null)
                return true
            }
            val rootId = DocumentsContract.getTreeDocumentId(uri)
            result.success(
                mapOf(
                    "treeUri" to uri.toString(),
                    "docId" to rootId,
                    "label" to rootId.substringAfterLast(':').ifBlank { "Storage" }
                )
            )
        } else {
            val uris = mutableListOf<Uri>()
            data.data?.let { uris.add(it) }
            if (uris.isEmpty()) {
                data.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
            }
            result.success(uris.map { describeTransient(it.toString()) })
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (pending != null && requestCode == MainActivity.REQ_PERMS) {
            val result = pending!!
            pending = null
            result.success(grantResults.isNotEmpty() && grantResults[0] == 0)
        }
    }

    private fun takePersistable(data: Intent) {
        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        val uris = mutableListOf<Uri>()
        data.data?.let { uris.add(it) }
        if (uris.isEmpty()) {
            data.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
            }
        }
        for (uri in uris) {
            try {
                resolver.takePersistableUriPermission(uri, flags)
            } catch (_: Exception) {
            }
        }
    }

    private fun persist(call: MethodCall): Boolean {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val write = call.argument<Boolean>("write") ?: false
        val flags = if (write) {
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        } else {
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        return try {
            resolver.takePersistableUriPermission(uri, flags)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun release(call: MethodCall): Boolean {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        return try {
            resolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasPersistable(call: MethodCall): Boolean {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        return resolver.persistedUriPermissions.any { it.uri == uri }
    }

    private fun listChildren(call: MethodCall): List<Map<String, Any?>> {
        val treeUri = tree(call)
        val parentId = call.argument<String>("docId") ?: DocumentsContract.getTreeDocumentId(treeUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
        val out = mutableListOf<Map<String, Any?>>()
        resolver.query(childrenUri, null, null, null, null)?.use { cursor ->
            val idIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val modIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val flagIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_FLAGS)
            while (cursor.moveToNext()) {
                val id = if (idIdx >= 0) cursor.getString(idIdx) else continue
                val mime = if (mimeIdx >= 0) cursor.getString(mimeIdx) else "application/octet-stream"
                val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR
                val flags = if (flagIdx >= 0) cursor.getInt(flagIdx) else 0
                val canCreate = (flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE) != 0
                val canWriteIt = (flags and DocumentsContract.Document.FLAG_SUPPORTS_WRITE) != 0
                out.add(
                    mapOf(
                        "docId" to id,
                        "name" to (if (nameIdx >= 0) cursor.getString(nameIdx) else id.substringAfterLast('/')),
                        "mime" to mime,
                        "isDir" to isDir,
                        "size" to (if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) cursor.getLong(sizeIdx) else -1L),
                        "modified" to (if (modIdx >= 0 && !cursor.isNull(modIdx)) cursor.getLong(modIdx) else 0L),
                        "canWrite" to ((isDir && canCreate) || canWriteIt),
                        "canDelete" to ((flags and DocumentsContract.Document.FLAG_SUPPORTS_DELETE) != 0),
                        "canRename" to ((flags and DocumentsContract.Document.FLAG_SUPPORTS_RENAME) != 0)
                    )
                )
            }
        }
        out.sortWith(
            compareByDescending<Map<String, Any?>> { it["isDir"] as Boolean }
                .thenBy { (it["name"] as String).lowercase() }
        )
        return out
    }

    private fun stat(call: MethodCall): Map<String, Any?> {
        val uri = doc(call)
        val meta = mapOf<String, Any?>(
            "docId" to docId(call),
            "treeUri" to call.argument<String>("treeUri"),
            "uri" to uri.toString()
        )
        val df = DocumentFile.fromSingleUri(activity, uri) ?: return meta
        return meta + mapOf(
            "name" to (df.name ?: ""),
            "mime" to (df.type ?: "application/octet-stream"),
            "isDir" to df.isDirectory,
            "size" to (if (df.exists() && df.isFile) df.length() else -1L),
            "modified" to df.lastModified()
        )
    }

    private fun cacheDir(): File = File(activity.cacheDir, "openfiles").apply { mkdirs() }

    private fun readToCache(call: MethodCall): Map<String, Any?> {
        val uri = if (call.argument<String>("treeUri") == null) {
            Uri.parse(call.argument<String>("path")!!)
        } else {
            doc(call)
        }
        val name = call.argument<String>("name") ?: "file.bin"
        val target = File(cacheDir(), "r_${System.nanoTime()}_$name")
        resolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output, 1 shl 16) }
        } ?: throw IllegalStateException("Cannot open $uri")
        return mapOf("path" to target.absolutePath, "size" to target.length())
    }

    private fun readBytes(call: MethodCall): ByteArray {
        val uri = if (call.argument<String>("treeUri") == null) {
            Uri.parse(call.argument<String>("path")!!)
        } else {
            doc(call)
        }
        val max = (call.argument<Number>("maxBytes")?.toLong() ?: 32L * 1024 * 1024).toInt()
        resolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(max)
            var read = 0
            while (read < max) {
                val n = input.read(buffer, read, max - read)
                if (n <= 0) break
                read += n
            }
            return if (read == max) buffer else buffer.copyOf(read)
        } ?: throw IllegalStateException("Cannot open $uri")
    }

    private fun writeFromPath(call: MethodCall): Boolean {
        val uri = if (call.argument<String>("treeUri") == null) {
            Uri.parse(call.argument<String>("path")!!)
        } else {
            doc(call)
        }
        val path = call.argument<String>("path")!!
        val append = call.argument<Boolean>("append") ?: false
        resolver.openOutputStream(uri, if (append) "wa" else "wt")?.use { output ->
            File(path).inputStream().use { it.copyTo(output, 1 shl 16) }
        } ?: throw IllegalStateException("Cannot write $uri")
        return true
    }

    private fun writeBytes(call: MethodCall): Boolean {
        val uri = if (call.argument<String>("treeUri") == null) {
            Uri.parse(call.argument<String>("path")!!)
        } else {
            doc(call)
        }
        val bytes = call.argument<ByteArray>("bytes")!!
        resolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("Cannot write $uri")
        return true
    }

    private fun createFile(call: MethodCall): String {
        val treeUri = tree(call)
        val parentId = call.argument<String>("docId")!!
        val name = call.argument<String>("name")!!
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        val dir = DocumentFile.fromTreeUri(activity, treeUri) ?: throw IllegalStateException("Bad tree")
        val parent = dir.findFile(parentId) ?: throw IllegalStateException("Missing parent")
        val file = parent.createFile(mime, name) ?: throw IllegalStateException("Create failed")
        if (file.name != null && file.name != name) {
            file.renameTo(name)
        }
        return file.uri.toString()
    }

    private fun createDir(call: MethodCall): String {
        val treeUri = tree(call)
        val parentId = call.argument<String>("docId")!!
        val name = call.argument<String>("name")!!
        val dir = DocumentFile.fromTreeUri(activity, treeUri) ?: throw IllegalStateException("Bad tree")
        val parent = dir.findFile(parentId) ?: throw IllegalStateException("Missing parent")
        val created = parent.createDirectory(name) ?: throw IllegalStateException("Mkdir failed")
        return created.uri.toString()
    }

    private fun deleteEntry(call: MethodCall): Boolean {
        val df = DocumentFile.fromSingleUri(activity, doc(call)) ?: return false
        if (df.isDirectory) {
            df.listFiles().forEach { it.delete() }
        }
        return df.delete()
    }

    private fun rename(call: MethodCall): Boolean {
        val df = DocumentFile.fromSingleUri(activity, doc(call)) ?: return false
        return df.renameTo(call.argument<String>("newName")!!)
    }

    private fun move(call: MethodCall): String {
        val copied = copy(call)
        deleteEntry(call)
        return copied
    }

    private fun copy(call: MethodCall): String {
        val source = doc(call)
        val targetTree = Uri.parse(call.argument<String>("destTreeUri")!!)
        val parentId = call.argument<String>("destDocId")!!
        val dir = DocumentFile.fromTreeUri(activity, targetTree)
            ?: throw IllegalStateException("Bad tree")
        val parent = dir.findFile(parentId) ?: throw IllegalStateException("Missing parent")
        val sourceName = call.argument<String>("name")
        val newName = call.argument<String>("newName")
            ?: sourceName
            ?: DocumentFile.fromSingleUri(activity, source)?.name
            ?: "copy"
        val mime = DocumentFile.fromSingleUri(activity, source)?.type
            ?: resolver.getType(source)
            ?: "application/octet-stream"

        val created = if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
            parent.createDirectory(newName)
        } else {
            parent.createFile(mime, newName)
        } ?: throw IllegalStateException("Copy failed")

        val from = DocumentFile.fromSingleUri(activity, source)
        if (from != null && from.isDirectory) {
            from.listFiles().forEach { child ->
                copyRecursive(child, created)
            }
        } else {
            resolver.openInputStream(source)?.use { input ->
                resolver.openOutputStream(created.uri, "wt")?.use { output ->
                    input.copyTo(output, 1 shl 16)
                } ?: throw IllegalStateException("Copy failed")
            } ?: throw IllegalStateException("Copy failed")
        }
        return created.uri.toString()
    }

    private fun copyRecursive(child: DocumentFile, destParent: DocumentFile) {
        val target = if (child.isDirectory) {
            destParent.createDirectory(child.name ?: "dir")
        } else {
            destParent.createFile(child.type ?: "application/octet-stream", child.name ?: "file")
        } ?: return
        if (child.isDirectory) {
            child.listFiles().forEach { copyRecursive(it, target) }
        } else {
            resolver.openInputStream(child.uri)?.use { input ->
                resolver.openOutputStream(target.uri, "wt")?.use { output ->
                    input.copyTo(output, 1 shl 16)
                }
            }
        }
    }

    private fun describeTransient(uriString: String): Map<String, Any?> {
        val uri = Uri.parse(uriString)
        var name = uri.lastPathSegment ?: "file"
        var size = -1L
        resolver.query(uri, null, null, null, null)?.use { c ->
            val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val si = c.getColumnIndex(OpenableColumns.SIZE)
            if (c.moveToFirst()) {
                if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni)
                if (si >= 0 && !c.isNull(si)) size = c.getLong(si)
            }
        }
        return mapOf(
            "uri" to uriString,
            "treeUri" to persistedTreeFor(uri),
            "name" to name,
            "mime" to (resolver.getType(uri) ?: "application/octet-stream"),
            "size" to size,
            "canWrite" to canWrite(uri)
        )
    }

    private fun canWrite(uri: Uri): Boolean =
        resolver.persistedUriPermissions.any { it.uri == uri && it.isWritePermission }

    private fun persistedTreeFor(uri: Uri): String? {
        val persisted = resolver.persistedUriPermissions
        for (p in persisted) {
            if (p.isReadPermission && p.uri.authority == uri.authority) return p.uri.toString()
        }
        return null
    }

    private fun appDirs(): Map<String, String> {
        val files = activity.filesDir
        val cache = cacheDir()
        val external = activity.getExternalFilesDir(null)
        return mapOf(
            "documents" to File(files, "documents").apply { mkdirs() }.absolutePath,
            "exports" to File(files, "exports").apply { mkdirs() }.absolutePath,
            "cache" to cache.absolutePath,
            "external" to (external?.absolutePath ?: files.absolutePath)
        )
    }

    private fun shareFile(call: MethodCall): Boolean {
        val path = call.argument<String>("path")!!
        val mime = call.argument<String>("mime") ?: "*/*"
        val uri = FileProvider.getUriForFile(
            activity,
            activity.packageName + ".fileprovider",
            File(path)
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, "Share"))
        return true
    }
}