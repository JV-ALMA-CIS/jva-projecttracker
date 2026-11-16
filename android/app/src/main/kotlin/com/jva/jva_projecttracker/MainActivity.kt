package com.jva.jva_projecttracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Creates the "general" channel every push targets (see
     * AndroidManifest.xml's default_notification_channel_id and
     * functions/matchScorePushNotification.js). IMPORTANCE_HIGH is what makes
     * a tender alert pop up as a heads-up banner with sound instead of
     * arriving silently in the tray. Creating an existing channel is a no-op,
     * so this is safe on every launch.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "general",
            "Opportunity alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New tenders and grants that match the company profile"
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }
}
