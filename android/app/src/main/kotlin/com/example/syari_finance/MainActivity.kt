package com.example.syari_finance

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "syari_finance/backup_files"
    private val saveRequestCode = 8101
    private val openRequestCode = 8102

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSource: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> saveBackup(
                        sourcePath = call.argument<String>("sourcePath"),
                        fileName = call.argument<String>("fileName"),
                        providerPackage = call.argument<String>("providerPackage"),
                        result = result,
                    )
                    "pickBackup" -> pickBackup(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveBackup(sourcePath: String?, fileName: String?, providerPackage: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Ada pemilih berkas yang masih terbuka.", null)
            return
        }
        val source = sourcePath?.let(::File)
        if (source == null || !source.exists()) {
            result.error("file_not_found", "Berkas backup sementara tidak ditemukan.", null)
            return
        }
        pendingResult = result
        pendingSource = source
        val saveIntent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, fileName ?: source.name)
        }
        if (!providerPackage.isNullOrBlank() &&
            packageManager.resolveActivity(saveIntent.setPackage(providerPackage), 0) == null) {
            saveIntent.setPackage(null)
        }
        startActivityForResult(saveIntent, saveRequestCode)
    }

    private fun pickBackup(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Ada pemilih berkas yang masih terbuka.", null)
            return
        }
        pendingResult = result
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            },
            openRequestCode,
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequestCode && requestCode != openRequestCode) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            finishSuccess(null)
            return
        }

        val uri = data.data ?: run {
            finishSuccess(null)
            return
        }
        if (requestCode == saveRequestCode) {
            saveToSelectedLocation(uri)
        } else {
            copySelectedBackupToCache(uri)
        }
    }

    private fun saveToSelectedLocation(uri: android.net.Uri) {
        val source = pendingSource ?: run {
            finishError("internal_error", "Berkas backup sementara tidak ditemukan.")
            return
        }
        Thread {
            try {
                source.inputStream().use { input ->
                    contentResolver.openOutputStream(uri)?.use { output ->
                        input.copyTo(output)
                    } ?: throw IllegalStateException("Lokasi tujuan tidak dapat ditulis.")
                }
                runOnUiThread { finishSuccess(uri.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    finishError("save_failed", error.localizedMessage ?: "Gagal menyimpan berkas backup.")
                }
            }
        }.start()
    }

    private fun copySelectedBackupToCache(uri: android.net.Uri) {
        Thread {
            try {
                val target = File.createTempFile("syari-restore-", ".syaribackup", cacheDir)
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: throw IllegalStateException("Berkas backup tidak dapat dibaca.")
                runOnUiThread { finishSuccess(target.absolutePath) }
            } catch (error: Exception) {
                runOnUiThread {
                    finishError("open_failed", error.localizedMessage ?: "Gagal membaca berkas backup.")
                }
            }
        }.start()
    }

    private fun finishSuccess(value: String?) {
        val result = pendingResult
        pendingResult = null
        pendingSource = null
        result?.success(value)
    }

    private fun finishError(code: String, message: String) {
        val result = pendingResult
        pendingResult = null
        pendingSource = null
        result?.error(code, message, null)
    }
}
