package com.vshots.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground lifetime, Android audio focus, MediaSession, and notification for
 * the one native WebView playback session.
 *
 * The WebView remains the media owner. This service never calls WebView.play,
 * never toggles playback, and never treats a metadata/position update as a
 * request to start audio. It only publishes the latest authoritative state
 * reported by VShotsBrowserPlatformView and forwards explicit transport
 * commands to Flutter.
 */
class VShotsBrowserPlaybackService : Service() {
    companion object {
        const val CHANNEL_ID = "vshots.browser.playback"
        const val NOTIFICATION_ID = 2401

        const val ACTION_UPDATE = "com.vshots.live.PLAYBACK_UPDATE"
        const val ACTION_PLAY = "com.vshots.live.PLAYBACK_PLAY"
        const val ACTION_PAUSE = "com.vshots.live.PLAYBACK_PAUSE"
        const val ACTION_NEXT = "com.vshots.live.PLAYBACK_NEXT"
        const val ACTION_PREVIOUS = "com.vshots.live.PLAYBACK_PREVIOUS"
        const val ACTION_REWIND = "com.vshots.live.PLAYBACK_REWIND"
        const val ACTION_FORWARD = "com.vshots.live.PLAYBACK_FORWARD"
        const val ACTION_STOP = "com.vshots.live.PLAYBACK_STOP"

        @Volatile
        var eventChannel: MethodChannel? = null

        @Volatile
        private var activeService: VShotsBrowserPlaybackService? = null

        /** Read-only position handoff from the WebView poll. It never starts
         * a service, requests focus, or republishes a notification. */
        fun updatePositionFromBrowser(
            positionMs: Long,
            durationMs: Long,
            generation: Long,
        ) {
            activeService?.acceptPosition(positionMs, durationMs, generation)
        }
    }

    private var title = "V Shots"
    private var artist = "Music playback"
    private var artworkUrl = ""
    private var playbackState = "idle"
    private var playing = false
    private var currentGeneration = -1L

    /** Last reported real media position (ms). */
    private var positionMs: Long = -1L
    private var durationMs: Long = -1L
    private var positionAt: Long = 0L

    private var mediaSession: MediaSession? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var focusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var focusHeld = false
    private var foregroundStarted = false
    private var lastNotificationSignature = ""
    private var lastArtworkUrl = ""
    @Volatile private var artworkGeneration = 0L

    /** Only a transient focus loss may resume automatically. */
    @Volatile private var pausedByFocusLoss = false

    /** Volume currently ducked by a transient sound. */
    @Volatile private var ducked = false

    override fun onCreate() {
        super.onCreate()
        activeService = this
        createNotificationChannel()
        createMediaSession()
        // startForeground is deliberately done by the first ACTION_UPDATE so
        // an orphaned service does not publish a fake PLAYING notification.
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> handleUpdate(intent)
            ACTION_PLAY -> {
                pausedByFocusLoss = false
                dispatch("play")
            }
            ACTION_PAUSE -> {
                pausedByFocusLoss = false
                dispatch("pause")
            }
            ACTION_NEXT -> dispatch("next")
            ACTION_PREVIOUS -> dispatch("previous")
            ACTION_REWIND -> dispatch("rewind")
            ACTION_FORWARD -> dispatch("fastForward")
            ACTION_STOP -> {
                pausedByFocusLoss = false
                dispatch("stop")
                abandonAudioFocus()
                stopForegroundCompat(remove = true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun acceptPosition(position: Long, duration: Long, generation: Long) {
        if (currentGeneration >= 0 && generation != currentGeneration) return
        if (position < 0) return
        positionMs = position
        if (duration >= 0) durationMs = duration
        positionAt = android.os.SystemClock.elapsedRealtime()
        // MediaSession progress is updated in place. Do not send an ACTION_
        // UPDATE back through the foreground-service transition path.
        updateMediaSession()
    }

    private fun handleUpdate(intent: Intent) {
        val incomingGeneration = intent.getLongExtra("generation", -1L)
        if (incomingGeneration >= 0 &&
            currentGeneration >= 0 &&
            incomingGeneration < currentGeneration
        ) {
            // Position/artwork callbacks from an old WebView generation must
            // not overwrite a newer track's notification.
            return
        }
        if (incomingGeneration >= 0) currentGeneration = incomingGeneration

        val oldActive = isActivePlayback()
        val oldPlaying = playing
        val oldTitle = title
        val oldArtist = artist
        val oldArtwork = artworkUrl
        val oldState = playbackState

        title = intent.getStringExtra("title")?.takeIf { it.isNotBlank() } ?: title
        artist = intent.getStringExtra("artist")?.takeIf { it.isNotBlank() } ?: artist
        artworkUrl = intent.getStringExtra("artwork")?.takeIf { it.isNotBlank() } ?: artworkUrl
        playbackState = intent.getStringExtra("state")?.takeIf { it.isNotBlank() }
            ?: if (intent.getBooleanExtra("playing", playing)) "playing" else "paused"
        playing = intent.getBooleanExtra("playing", playing)

        when (intent.getStringExtra("userCommand")) {
            "pause", "play" -> pausedByFocusLoss = false
        }

        val newPositionMs = intent.getLongExtra("positionMs", -1L)
        if (newPositionMs >= 0) {
            positionMs = newPositionMs
            positionAt = android.os.SystemClock.elapsedRealtime()
        } else if (!isActivePlayback() && positionMs >= 0) {
            positionMs = currentEstimatedPositionMs()
            positionAt = android.os.SystemClock.elapsedRealtime()
        }
        val newDurationMs = intent.getLongExtra("durationMs", -1L)
        if (newDurationMs >= 0) durationMs = newDurationMs

        val newActive = isActivePlayback()
        // Focus follows the authoritative state transition, not every
        // position/metadata update. A failed request is not retried by the
        // polling/notification loop; the next real inactive→playing
        // transition can request it again.
        if (newActive && !oldActive) {
            requestAudioFocus()
        } else if (!newActive && oldActive) {
            abandonAudioFocus()
        }
        if (!newActive && !oldActive && !oldPlaying) {
            // An explicit user PAUSE is authoritative. In particular it clears
            // the transient-loss resume latch before a later focus gain.
            if (intent.getStringExtra("userCommand") == "pause") {
                pausedByFocusLoss = false
            }
        }

        updateMediaSession()

        val metadataChanged = title != oldTitle || artist != oldArtist || artworkUrl != oldArtwork
        val stateChanged = playbackState != oldState || playing != oldPlaying
        val signature = notificationSignature()
        if (!foregroundStarted || metadataChanged || stateChanged || signature != lastNotificationSignature) {
            publishNotification()
        }

        if (artworkUrl.isNotBlank() && artworkUrl != lastArtworkUrl) {
            lastArtworkUrl = artworkUrl
            val generation = ++artworkGeneration
            loadArtworkAsync(artworkUrl, generation)
        }
    }

    /** Focus is held only for actual audible playback. Buffering/ad retain an
     * already-held focus while the media element was playing, but a fresh
     * loading/buffering state with playing=false never requests focus. */
    private fun isActivePlayback(): Boolean =
        playbackState == "playing" ||
            (playing && (playbackState == "buffering" || playbackState == "ad"))

    // ── Audio focus ─────────────────────────────────────────────────────────

    private fun ensureFocusListener() {
        if (focusListener != null) return
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        focusListener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS -> {
                    pausedByFocusLoss = false
                    ducked = false
                    abandonAudioFocus()
                    dispatch("pause")
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    if (isActivePlayback()) pausedByFocusLoss = true
                    ducked = false
                    dispatch("focusPause")
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                    if (isActivePlayback()) {
                        ducked = true
                        dispatch("duckOn")
                    }
                }
                AudioManager.AUDIOFOCUS_GAIN -> {
                    if (ducked) {
                        ducked = false
                        dispatch("duckOff")
                    }
                    if (pausedByFocusLoss) {
                        pausedByFocusLoss = false
                        dispatch("focusPlay")
                    }
                }
            }
        }
    }

    private fun requestAudioFocus() {
        ensureFocusListener()
        val am = audioManager ?: return
        val listener = focusListener ?: return
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setOnAudioFocusChangeListener(listener)
                .setWillPauseWhenDucked(false)
                .build()
                .also { focusRequest = it }
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                listener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
        focusHeld = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus() {
        val am = audioManager ?: run {
            focusHeld = false
            return
        }
        if (!focusHeld) return
        focusHeld = false
        ducked = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            focusListener?.let { am.abandonAudioFocus(it) }
        }
    }

    // ── MediaSession ────────────────────────────────────────────────────────

    private fun createMediaSession() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        mediaSession = MediaSession(this, "VShotsBrowser").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    pausedByFocusLoss = false
                    dispatch("play")
                }

                override fun onPause() {
                    pausedByFocusLoss = false
                    dispatch("pause")
                }

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

    private fun updateMediaSession(artwork: Bitmap? = null) {
        val session = mediaSession ?: return
        val actions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_FAST_FORWARD or
            PlaybackState.ACTION_REWIND or
            PlaybackState.ACTION_STOP
        val state = when (playbackState) {
            "playing" -> PlaybackState.STATE_PLAYING
            "buffering", "loading", "ad" -> PlaybackState.STATE_BUFFERING
            "paused" -> PlaybackState.STATE_PAUSED
            "ended" -> PlaybackState.STATE_STOPPED
            "error" -> PlaybackState.STATE_ERROR
            else -> PlaybackState.STATE_NONE
        }
        val position = if (positionMs >= 0) currentEstimatedPositionMs()
        else PlaybackState.PLAYBACK_POSITION_UNKNOWN
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(state, position, if (state == PlaybackState.STATE_PLAYING) 1.0f else 0.0f)
                .build(),
        )

        val metadataBuilder = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, artist)
        if (durationMs > 0) {
            metadataBuilder.putLong(android.media.MediaMetadata.METADATA_KEY_DURATION, durationMs)
        }
        if (artwork != null) {
            metadataBuilder.putBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART, artwork)
            metadataBuilder.putBitmap(android.media.MediaMetadata.METADATA_KEY_ART, artwork)
        }
        session.setMetadata(metadataBuilder.build())
    }

    private fun currentEstimatedPositionMs(): Long {
        if (positionMs < 0) return PlaybackState.PLAYBACK_POSITION_UNKNOWN
        if (!isActivePlayback()) return positionMs
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

    // ── Notification ────────────────────────────────────────────────────────

    private fun notificationSignature(): String =
        "$title\u0000$artist\u0000$artworkUrl\u0000$playbackState\u0000$playing"

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
        if (durationMs > 0) {
            val progress = currentEstimatedPositionMs().coerceIn(0L, durationMs)
            notificationBuilder.setProgress(durationMs.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), progress.toInt(), false)
        }

        addAction(
            notificationBuilder,
            android.R.drawable.ic_media_previous,
            "Previous",
            ACTION_PREVIOUS,
            2403,
        )
        addAction(
            notificationBuilder,
            android.R.drawable.ic_media_rew,
            "Rewind 10 seconds",
            ACTION_REWIND,
            2404,
        )
        addAction(
            notificationBuilder,
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (playing) "Pause" else "Play",
            if (playing) ACTION_PAUSE else ACTION_PLAY,
            2405,
        )
        addAction(
            notificationBuilder,
            android.R.drawable.ic_media_ff,
            "Forward 10 seconds",
            ACTION_FORWARD,
            2406,
        )
        addAction(
            notificationBuilder,
            android.R.drawable.ic_media_next,
            "Next",
            ACTION_NEXT,
            2407,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notificationBuilder.setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 2, 4),
            )
        }

        val notification = notificationBuilder.build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            foregroundStarted = true
            manager?.notify(NOTIFICATION_ID, notification)
            lastNotificationSignature = notificationSignature()
        } catch (_: Throwable) {
            // Android may reject foreground promotion during teardown; the
            // playback session must remain alive and not crash the process.
        }
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
                if (generation == artworkGeneration && url == artworkUrl) {
                    updateMediaSession(bitmap)
                    publishNotification(bitmap)
                }
            } catch (_: Throwable) {
                // Artwork is enhancement only; transport controls remain usable.
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

    private fun stopForegroundCompat(remove: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(
                if (remove) Service.STOP_FOREGROUND_REMOVE else Service.STOP_FOREGROUND_DETACH,
            )
        } else {
            @Suppress("DEPRECATION")
            stopForeground(remove)
        }
        foregroundStarted = false
    }

    override fun onDestroy() {
        if (activeService === this) activeService = null
        abandonAudioFocus()
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        eventChannel = null
        stopForegroundCompat(remove = true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
