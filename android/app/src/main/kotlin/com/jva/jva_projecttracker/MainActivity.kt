package com.jva.jva_projecttracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * One channel per kind of alert, so each person can mute e.g. the weekly
     * summary in Android settings without losing tender alerts. Channel ids
     * must match `channelForType` in functions/matchScorePushNotification.js
     * and `kAndroidChannels` in lib/services/push_notification_service.dart.
     * "general" stays the manifest default (test pushes, and the fallback
     * when a push names a channel an older install doesn't have).
     * IMPORTANCE_HIGH = heads-up banner + sound. Re-creating an existing
     * channel only updates its name/description, so this is safe every launch.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channels = listOf(
            Triple("opportunities", "New tenders & grants", "New tenders, grants and calls that match the company"),
            Triple("deadlines", "Deadline reminders", "Deadlines coming up for opportunities we're following"),
            Triple("team", "Shared by colleagues", "Opportunities a colleague added or shared with the team"),
            Triple("summary", "Weekly summary", "Monday overview of what's open"),
            Triple("general", "Other alerts", "Test notifications and other alerts"),
        )
        for ((id, name, description) in channels) {
            val importance =
                if (id == "summary") NotificationManager.IMPORTANCE_DEFAULT
                else NotificationManager.IMPORTANCE_HIGH
            manager.createNotificationChannel(
                NotificationChannel(id, name, importance).apply {
                    this.description = description
                    enableVibration(importance == NotificationManager.IMPORTANCE_HIGH)
                },
            )
        }
    }
}
