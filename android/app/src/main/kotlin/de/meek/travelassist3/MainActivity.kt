package de.meek.travelassist3

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingShare: Map<String, List<String>>? = null
    private var dartReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity gets the old intent again; don't process that share twice.
        if (savedInstanceState == null) handleShare(intent)
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        dartReady = true
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    "openUri" -> result.success(openUri(call.arguments as? String))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShare(intent)
    }

    private fun handleShare(intent: Intent?) {
        val share = readShare(intent) ?: return
        // Copying large photos must not block the UI thread.
        executor.execute {
            val result = mapOf(
                "texts" to share.first,
                "uris" to share.second.map { keepAccessible(it) },
            )
            runOnUiThread {
                if (dartReady) channel?.invokeMethod("onShare", result) else pendingShare = result
            }
        }
    }

    private fun readShare(intent: Intent?): Pair<List<String>, List<Uri>>? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }

        val texts = mutableListOf<String>()
        intent.getStringExtra(Intent.EXTRA_TEXT)?.let { texts.add(it) }

        val uris = linkedSetOf<Uri>()
        @Suppress("DEPRECATION")
        when (intent.action) {
            Intent.ACTION_SEND ->
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
            else ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
        }
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { uris.add(it) }
        }

        if (texts.isEmpty() && uris.isEmpty()) return null

        return Pair(texts, uris.toList())
    }

    /**
     * A shared URI is only readable for a short time. Keep it if Android allows a persistent
     * grant, otherwise copy the file into the app and return a URI of the app's own provider.
     */
    private fun keepAccessible(uri: Uri): String {
        if (uri.scheme != "content" || uri.authority == "$packageName.fileprovider") {
            return uri.toString()
        }
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            return uri.toString()
        } catch (_: Exception) {
        }
        return try {
            val extension = contentResolver.getType(uri)
                ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            val dir = File(filesDir, "shared").apply { mkdirs() }
            val file = File(dir, UUID.randomUUID().toString() + (extension?.let { ".$it" } ?: ""))
            contentResolver.openInputStream(uri)!!.use { input ->
                file.outputStream().use { input.copyTo(it) }
            }
            FileProvider.getUriForFile(this, "$packageName.fileprovider", file).toString()
        } catch (_: Exception) {
            uri.toString()
        }
    }

    private fun openUri(value: String?): Boolean {
        if (value == null) return false
        return try {
            val uri = Uri.parse(value)
            val type = try {
                contentResolver.getType(uri)
            } catch (_: Exception) {
                null
            }
            val view = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, type ?: "image/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(view)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "de.meek.travelassist3/share"
    }
}
