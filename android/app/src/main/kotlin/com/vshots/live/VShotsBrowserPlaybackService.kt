package com.vshots.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL

/**
 * Android foreground media notification for the official browser player.
 *
 * The WebView remains the playback owner. This service owns only the Android
 * foreground lifetime and native MediaStyle notification chrome. All commands
 * are forwarded to the active Flutter/native browser session.
 */
class VShotsBrowserPlaybackService : Service() {
    companion object {
        const val CHANNEL_ID = "vshots.browser.playback"
        const val NOTIFICATION_ID = 2401

        const val ACTION_UPDATE = "com.vshots.live.PLAYBACK_UPDATE"
        const val ACTION_TOGGLE = "com.vshots.live.PLAYBACK_TOGGLE"
        const val ACTION_NEXT = "com.vshots.live.PLAYBACK_NEXT"
        const val ACTION_PREVIOUS = "com.vshots.live.PLAYBACK_PREVIOUS"
        const val ACTION_REWIND = "com.vshots.live.PLAYBACK_REWIND"
        const val ACTION_FORWARD = "com.vshots.live.PLAYBACK_FORWARD"
        const val ACTION_STOP = "com.vshots.live.PLAYBACK_STOP"

        @Volatile
        var eventChannel: MethodChannel? = null
    }

    private var title = "V Shots"
    private var artist = "Music playback"
    private var artworkUrl = ""
    private var playing = false

    /** Last reported real media position (ms) — drives the notification
     *  progress bar. -1 = unknown (keep PLAYBACK_POSITION_UNKNOWN). */
    private var positionMs: Long = -1L
    private var durationMs: Long = -1L
    private var positionAt: Long = 0L // elapsedRealtime anchor for extrapolation
    private var mediaSession: MediaSession? = null
    @Volatile private var artworkGeneration = 0L

    // ── Audio focus (phone calls, other media apps, notifications) ─────────
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var focusListener: AudioManager.OnAudioFocusChangeListener? = null

    /** Paused by a TRANSIENT focus loss we are allowed to resume from. */
    @Volatile private var pausedByFocusLoss = false

    /** Volume currently ducked (e.g. a navigation prompt is speaking). */
    @Volatile private var ducked = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        createMediaSession()
        publishNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> {
                title = intent.getStringExtra("title")?.takeIf { it.isNotBlank() } ?: "V Shots"
                artist = intent.getStringExtra("artist")?.takeIf { it.isNotBlank() } ?: "Music playback"
                artworkUrl = intent.getStringExtra("artwork")?.takeIf { it.isNotBlank() } ?: ""
                playing = intent.getBooleanExtra("playing", playing)
                val newPositionMs = intent.getLongExtra("positionMs", -1L)
                if (newPositionMs >= 0) {
                    positionMs = newPositionMs
                    positionAt = android.os.SystemClock.elapsedRealtime()
                } else if (!playing && positionMs >= 0) {
                    // Pause freezes the bar at the current estimate.
                    positionMs = currentEstimatedPositionMs()
                    positionAt = android.os.SystemClock.elapsedRealtime()
                }
                durationMs = intent.getLongExtra("durationMs", durationMs)
                val generation = ++artworkGeneration
                // Media apps must hold audio focus while audible. Requesting
                // while already held is a cheap no-op grant.
                if (playing) requestAudioFocus()
                updateMediaSession()
                publishNotification()
                if (artworkUrl.isNotBlank()) loadArtworkAsync(artworkUrl, generation)
            }
            ACTION_TOGGLE -> dispatch("toggle")
            ACTION_NEXT -> dispatch("next")
            ACTION_PREVIOUS -> dispatch("previous")
            ACTION_REWIND -> dispatch("rewind")
            ACTION_FORWARD -> dispatch("fastForward")
            ACTION_STOP -> {
                dispatch("stop")
                abandonAudioFocus()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    // ── Audio focus implementation ──────────────────────────────────────────

    /**
     * Focus rules (owner spec — phone-call & interruption handling):
     *  • AUDIOFOCUS_LOSS            → pause, NO auto-resume (another app owns audio)
     *  • AUDIOFOCUS_LOSS_TRANSIENT  → pause, auto-resume on regain (phone call)
     *  • AUDIOFOCUS_LOSS_CAN_DUCK   → duck to 15% volume, restore on regain
     */
    private fun ensureFocusListener() {
        if (focusListener != null) return
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        focusListener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS -> {
                    pausedByFocusLoss = false
                    ducked = false
                    dispatch("pause")
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    if (playing) pausedByFocusLoss = true
                    ducked = false
                    dispatch("pause")
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                    ducked = true
                    dispatch("duckOn")
                }
                AudioManager.AUDIOFOCUS_GAIN -> {
                    if (ducked) {
                        ducked = false
                        dispatch("duckOff")
                    }
                    if (pausedByFocusLoss) {
                        pausedByFocusLoss = false
                        dispatch("play")
                    }
                }
            }
        }
    }

    private fun requestAudioFocus() {
        ensureFocusListener()
        val am = audioManager ?: return
        val listener = focusListener ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(listener)
                .setWillPauseWhenDucked(false)
                .build()
                .also { focusRequest = it }
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonAudioFocus() {
        val am = audioManager ?: return
        pausedByFocusLoss = false
        ducked = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            focusListener?.let { am.abandonAudioFocus(it) }
        }
    }

    private fun createMediaSession() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        mediaSession = MediaSession(this, "VShotsBrowser").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = dispatch("play")
                override fun onPause() = dispatch("pause")
                override fun onSkipToNext() = dispatch("next")
                override fun onSkipToPrevious() = dispatch("previous")
                override fun onFastForward() = dispatch("fastForward")
                override fun onRewind() = dispatch("rewind")
                override fun onStop() = dispatch("stop")
            })
            isActive = true
        }
        updateMediaSession()
    }

    private fun updateMediaSession() {
        val session = mediaSession ?: return
        val actions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_FAST_FORWARD or
            PlaybackState.ACTION_REWIND or
            PlaybackState.ACTION_STOP
        val state = if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        // Real position when known: the system extrapolates a moving
        // progress bar from (position, speed, anchor time) between updates.
        val position = if (positionMs >= 0) currentEstimatedPositionMs()
            else PlaybackState.PLAYBACK_POSITION_UNKNOWN
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(state, position, if (playing) 1.0f else 0.0f)
                .build(),
        )
    }

    /** Position estimate between probes: anchor + elapsed while playing. */
    private fun currentEstimatedPositionMs(): Long {
        if (positionMs < 0) return PlaybackState.PLAYBACK_POSITION_UNKNOWN
        if (!playing) return positionMs
        val elapsed = android.os.SystemClock.elapsedRealtime() - positionAt
        val estimate = positionMs + elapsed
        return if (durationMs > 0) minOf(estimate, durationMs) else estimate
    }

    private fun dispatch(action: String) {
        try {
            eventChannel?.invokeMethod("notificationAction", action)
        } catch (_: Throwable) {
            // Notification commands are best effort; never crash playback.
        }
    }

    fun update(title: String?, artist: String?, playing: Boolean) {
        this.title = title?.takeIf { it.isNotBlank() } ?: "V Shots"
        this.artist = artist?.takeIf { it.isNotBlank() } ?: "Music playback"
        this.playing = playing
        updateMediaSession()
        publishNotification()
    }

    private fun publishNotification(artwork: Bitmap? = null) {
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

        val notificationBuilder = builder
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText("V Shots")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)

        if (artwork != null) notificationBuilder.setLargeIcon(artwork)

        // Five transport controls: previous, -10s, play/pause, +10s, next.
        // Android may show the compact three-action subset, while expanded
        // MediaStyle exposes the complete transport row.
        addAction(notificationBuilder, android.R.drawable.ic_media_previous, "Previous", ACTION_PREVIOUS, 2403)
        addAction(notificationBuilder, android.R.drawable.ic_media_rew, "Rewind 10 seconds", ACTION_REWIND, 2404)
        addAction(
            notificationBuilder,
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (playing) "Pause" else "Play",
            ACTION_TOGGLE,
            2405,
        )
        addAction(notificationBuilder, android.R.drawable.ic_media_ff, "Forward 10 seconds", ACTION_FORWARD, 2406)
        addAction(notificationBuilder, android.R.drawable.ic_media_next, "Next", ACTION_NEXT, 2407)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notificationBuilder.setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 2, 4),
            )
        }

        val notification = notificationBuilder.build()
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

    private fun addAction(
        builder: Notification.Builder,
        icon: Int,
        label: String,
        action: String,
        requestCode: Int,
    ) {
        builder.addAction(
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, icon),
                label,
                actionIntent(action, requestCode),
            ).build(),
        )
    }

    private fun loadArtworkAsync(url: String, generation: Long) {
        Thread {
            var connection: HttpURLConnection? = null
            try {
                connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 5000
                connection.readTimeout = 7000
                connection.instanceFollowRedirects = true
                connection.connect()
                if (connection.responseCode !in 200..299) return@Thread
                val bitmap = connection.inputStream.use { BitmapFactory.decodeStream(it) } ?: return@Thread
                if (generation == artworkGeneration && url == artworkUrl) publishNotification(bitmap)
            } catch (_: Throwable) {
                // Artwork is enhancement only; notification remains usable.
            } finally {
                connection?.disconnect()
            }
        }.start()
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
        abandonAudioFocus()
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        eventChannel = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
