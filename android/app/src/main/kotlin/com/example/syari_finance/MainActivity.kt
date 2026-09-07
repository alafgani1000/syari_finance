package com.example.syari_finance

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val backupChannelName = "syari_finance/backup_files"
    private val reminderChannelName = "syari_finance/due_reminders"
    private val saveRequestCode = 8101
    private val openRequestCode = 8102
    private val notificationPermissionRequestCode = 8103

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSource: File? = null
    private var pendingDestination: String? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> saveBackup(
                        sourcePath = call.argument<String>("sourcePath"),
                        fileName = call.argument<String>("fileName"),
                        destination = call.argument<String>("destination"),
                        result = result,
                    )
                    "pickBackup" -> pickBackup(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(notificationPermissionGranted())
                    "requestPermission" -> {
                        if (notificationPermissionGranted()) {
                            result.success(true)
                        } else if (pendingNotificationPermissionResult != null) {
                            result.error("busy", "Permintaan izin notifikasi masih berlangsung.", null)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            pendingNotificationPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequestCode)
                        } else {
                            result.success(true)
                        }
                    }
                    "schedule" -> scheduleReminders(
                        call.argument<List<Map<String, Any?>>>("reminders") ?: emptyList(),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequestCode) return
        val result = pendingNotificationPermissionResult
        pendingNotificationPermissionResult = null
        result?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }
    private fun notificationPermissionGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun scheduleReminders(reminders: List<Map<String, Any?>>, result: MethodChannel.Result) {
        if (!notificationPermissionGranted()) {
            result.error("permission_denied", "Izinkan notifikasi Android terlebih dahulu.", null)
            return
        }
        val alarmManager = getSystemService(AlarmManager::class.java)
        val preferences = getSharedPreferences("due_reminders", MODE_PRIVATE)
        val scheduledIds = reminders.mapNotNull { (it["id"] as? Number)?.toInt() }.toSet()
        val previousIds = preferences.getStringSet("ids", emptySet()) ?: emptySet()
        previousIds.mapNotNull { it.toIntOrNull() }.filter { it !in scheduledIds }.forEach { id ->
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id,
                Intent(this, DueReminderReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
        var scheduled = 0
        try {
            reminders.forEach { reminder ->
                val id = (reminder["id"] as? Number)?.toInt() ?: return@forEach
                val timestamp = (reminder["timestamp"] as? Number)?.toLong() ?: return@forEach
                if (timestamp <= System.currentTimeMillis()) return@forEach
                val intent = Intent(this, DueReminderReceiver::class.java).apply {
                    putExtra(DueReminderReceiver.extraId, id)
                    putExtra(DueReminderReceiver.extraTitle, reminder["title"] as? String ?: "Jatuh tempo angsuran")
                    putExtra(DueReminderReceiver.extraBody, reminder["body"] as? String ?: "Periksa pembayaran nasabah.")
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    id,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
                }
                scheduled++
            }
            preferences.edit().putStringSet("ids", scheduledIds.map { it.toString() }.toSet()).apply()
            result.success(scheduled)
        } catch (error: SecurityException) {
            result.error("alarm_permission", "Aktifkan izin alarm & pengingat di pengaturan Android agar jadwal tepat waktu.", null)
        }
    }

    private fun saveBackup(
        sourcePath: String?,
        fileName: String?,
        destination: String?,
        result: MethodChannel.Result,
    ) {
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
        pendingDestination = destination
        val saveIntent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, fileName ?: source.name)
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
        if (pendingDestination == "googleDrive" &&
            uri.authority != "com.google.android.apps.docs.storage"
        ) {
            finishError(
                "wrong_destination",
                "Google Drive belum dipilih. Pada pemilih Android, pilih Google Drive lalu tentukan foldernya.",
            )
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
        pendingDestination = null
        result?.success(value)
    }

    private fun finishError(code: String, message: String) {
        val result = pendingResult
        pendingResult = null
        pendingSource = null
        pendingDestination = null
        result?.error(code, message, null)
    }
}