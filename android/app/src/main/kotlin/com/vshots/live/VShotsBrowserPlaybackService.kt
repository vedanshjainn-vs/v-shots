package com.vshots.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel

/**
 * Android foreground media notification for the official browser player.
 *
 * The WebView remains the playback owner. This service only owns the Android
 * foreground lifetime and notification chrome; commands are forwarded to the
 * active Flutter/native browser session through its MethodChannel.
 */
class VShotsBrowserPlaybackService : Service() {
    companion object {
        const val CHANNEL_ID = "vshots.browser.playback"
        const val NOTIFICATION_ID = 2401

        const val ACTION_UPDATE = "com.vshots.live.PLAYBACK_UPDATE"
        const val ACTION_TOGGLE = "com.vshots.live.PLAYBACK_TOGGLE"
        const val ACTION_NEXT = "com.vshots.live.PLAYBACK_NEXT"
        const val ACTION_PREVIOUS = "com.vshots.live.PLAYBACK_PREVIOUS"
        const val ACTION_STOP = "com.vshots.live.PLAYBACK_STOP"

        @Volatile
        var eventChannel: MethodChannel? = null
    }

    private var title = "V Shots"
    private var artist = "Music playback"
    private var playing = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        publishNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> {
                title = intent.getStringExtra("title")?.takeIf { it.isNotBlank() } ?: "V Shots"
                artist = intent.getStringExtra("artist")?.takeIf { it.isNotBlank() } ?: "Music playback"
                playing = intent.getBooleanExtra("playing", playing)
                publishNotification()
            }
            ACTION_TOGGLE -> dispatch("toggle")
            ACTION_NEXT -> dispatch("next")
            ACTION_PREVIOUS -> dispatch("previous")
            ACTION_STOP -> {
                dispatch("stop")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun dispatch(action: String) {
        try {
            eventChannel?.invokeMethod("notificationAction", action)
        } catch (_: Throwable) {
            // Notification commands are best effort; the foreground service
            // must never crash the playback process.
        }
    }

    fun update(title: String?, artist: String?, playing: Boolean) {
        this.title = title?.takeIf { it.isNotBlank() } ?: "V Shots"
        this.artist = artist?.takeIf { it.isNotBlank() } ?: "Music playback"
        this.playing = playing
        publishNotification()
    }

    private fun publishNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            2402,
            openIntent,
            pendingIntentFlags(),
        )

        val previous = actionIntent(ACTION_PREVIOUS, 2403)
        val toggle = actionIntent(ACTION_TOGGLE, 2404)
        val next = actionIntent(ACTION_NEXT, 2405)
        val stop = actionIntent(ACTION_STOP, 2406)

        val notification = builder
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(if (playing) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .addAction(Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_previous),
                "Previous",
                previous,
            ).build())
            .addAction(Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(
                    this,
                    if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                ),
                if (playing) "Pause" else "Play",
                toggle,
            ).build())
            .addAction(Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_next),
                "Next",
                next,
            ).build())
            .addAction(Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
                "Stop",
                stop,
            ).build())
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        manager?.notify(NOTIFICATION_ID, notification)
    }

    private fun actionIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, VShotsBrowserPlaybackService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(this, requestCode, intent, pendingIntentFlags())
    }

    private fun pendingIntentFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return flags
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "V Shots browser playback",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Playback controls for V Shots music"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    override fun onDestroy() {
        eventChannel = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
