package com.example.syari_finance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class DueReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Pengingat jatuh tempo", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Pengingat angsuran Arafah Finance"
                },
            )
        }
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(intent.getStringExtra(extraTitle) ?: "Jatuh tempo angsuran")
            .setContentText(intent.getStringExtra(extraBody) ?: "Periksa pembayaran nasabah.")
            .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra(extraBody)))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        manager.notify(intent.getIntExtra(extraId, 0), builder.build())
    }

    companion object {
        const val channelId = "due_reminders"
        const val extraId = "id"
        const val extraTitle = "title"
        const val extraBody = "body"
    }
}