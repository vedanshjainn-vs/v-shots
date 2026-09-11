package com.vshots.live

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.Locale

private const val VIEW_TYPE = "vshots/native_browser"
private const val TAG = "VShotsPlayback"

/**
 * App-wide YouTube playback assist (owner spec, Phase 17.10):
 *
 *  • COMPLETION OBSERVATION — the real media element reports a validated
 *    near-end/end event. The Flutter queue owner decides whether to advance;
 *    this WebView never starts another track from its polling callback.
 *
 *  • AD ASSIST — while the OFFICIAL YouTube player runs an in-stream ad:
 *      - the ad is muted (only the player's own video element state);
 *      - YouTube's own "Skip" button is clicked when it appears (the exact
 *        action a user would take; unskippable ads play muted in full);
 *      - nothing is blocked, hidden, resized or sped up; no ad-network
 *        interception, no unofficial APIs, no stream access.
 *    Ad completion is observed only; an explicit/system Play command owns
 *    any subsequent content transition.
 *
 * Only official, user-equivalent player controls are used. The assist is
 * gated by the remote flag `enable_youtube_ad_assist` (default ON) and is
 * YouTube-page-only — JioSaavn pages are never touched.
 */

/**
 * One-per-second playback poll. Returns:
 *   'ad'      — an in-stream ad is playing (player's own ad UI markers)
 *   'ended'   — media reached its natural end
 *   'nearend' — <=1.5 s left AND still playing (never while paused)
 *   'paused' / 'playing' / 'buffering' / 'none' / 'unknown'
 */
private const val YT_POLL_JS = """
(function(){
  try{
    var adOn = !!document.querySelector('.ad-showing');
    if(!adOn){
      var ui = document.querySelector('.videoAdUi, .ytp-ad-player-overlay');
      if(ui && ui.offsetParent !== null){ adOn = true; }
    }
    var v = document.querySelector('video,audio');
    if(!v){ return adOn ? 'ad' : 'none'; }
    if(adOn){ return 'ad'; }
    if(v.ended){ return 'ended'; }
    if(v.seeking || (!v.paused && v.readyState < 3)){ return 'buffering'; }
    var d = v.duration;
    if(d && isFinite(d) && !v.paused && v.currentTime >= d - 1.5){ return 'nearend'; }
    return v.paused ? 'paused' : 'playing';
  }catch(e){ return 'unknown'; }
})()
"""

/**
 * Position probe (every few poll ticks while playing): returns
 * "<positionMs>|<durationMs>" from the REAL media element so the media
 * session can render an accurate lock-screen/notification progress bar.
 * Returns "none" when no media element exists.
 */
private const val YT_POSITION_JS = """
(function(){
  try{
    var v=document.querySelector('video,audio');
    if(!v){ return 'none'; }
    var d=(v.duration&&isFinite(v.duration))?Math.round(v.duration*1000):-1;
    return Math.round(v.currentTime*1000)+'|'+d;
  }catch(e){ return 'none'; }
})()
"""

/**
 * Ad assist pass (runs each poll tick while an ad is active): mute the ad
 * audio, and click YouTube's OWN visible Skip button when it is shown.
 * Returns 'skipped' when a skip was clicked, 'muted' when only muted,
 * 'ok' when nothing needed doing.
 */
private const val YT_AD_ASSIST_JS = """
(function(){
  try{
    var skipped = false;
    var v = document.querySelector('video');
    if(v && !v.muted){ v.muted = true; v.volume = 0; }
    var sels = ['button.ytp-ad-skip-button','button.ytp-skip-ad-button',
                '.ytp-ad-skip-button-modern button','button.ytp-ad-skip-button-modern'];
    for(var i=0;i<sels.length;i++){
      var b = document.querySelector(sels[i]);
      if(b && b.offsetParent !== null && !b.disabled){
        try{ b.click(); skipped = true; }catch(e){}
        break;
      }
    }
    return skipped ? 'skipped' : 'muted';
  }catch(e){ return 'err'; }
})()
"""

/**
 * Discovery-only native browser view with FORCEFUL ad blocking.
 *
 * Third-party ad blocking for non-YouTube pages. YouTube watch-page
 * resources (including YouTube ads) are never intercepted or hidden.
 *
 * Unlike the generic webview_flutter platform view, this WebView deliberately
 * keeps its media lifecycle alive when Android makes the Flutter activity
 * invisible. This is the critical part for long-form audio/video continuity
 * while the Discovery browser is minimized, backgrounded, or the screen is
 * locked.
 */
private class VShotsBackgroundMediaWebView(
    context: Context,
    private val events: MethodChannel,
) : WebView(context) {

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())

    /** Monotonic load generation. Every async JS callback captures it so a
     * stale page cannot mutate the next track's state. */
    private var loadGeneration = 0L
    private var currentLoadUrl = ""
    private var playbackState = "idle"
    private var notificationTitle = "V Shots"
    private var notificationArtist = "Music playback"
    private var notificationArtwork = ""

    // ── FORCEFUL Ad Blocker State ──────────────────────────────────────────
    // ALWAYS ON by default. Populated from Dart via "setContentBlocker".
    // Host-exact + suffix matching + URL pattern matching.
    // Essential/allow hosts always pass (media must never be blocked).
    private var blockerEnabled = true
    private val blockedHosts = mutableSetOf<String>()
    private val essentialHosts = mutableSetOf<String>()
    private val adUrlPatterns = mutableListOf<String>()

    // Popup blocking state
    private var popupBlockedCount = 0

    private val playbackPoll = object : Runnable {
        private var tick = 0

        fun reset() {
            tick = 0
        }

        override fun run() {
            if (!isAttachedToWindow && !mediaPlaying) return
            val generation = loadGeneration
            evaluateJavascript(YT_POLL_JS) { result ->
                if (generation == loadGeneration) {
                    handlePollResult(cleanJsResult(result), generation)
                }
            }
            // Every ~5s while playing: report real position/duration. Position
            // is read-only and does not request focus or change play state.
            if (mediaPlaying && tick % 5 == 0) {
                evaluateJavascript(YT_POSITION_JS) { result ->
                    if (generation == loadGeneration) {
                        handlePositionResult(cleanJsResult(result), generation)
                    }
                }
            }
            tick++
            handler.postDelayed(this, 1000L)
        }
    }

    private fun handlePositionResult(result: String, generation: Long) {
        if (generation != loadGeneration || result == "none" || !result.contains("|")) return
        val parts = result.split("|")
        val positionMs = parts[0].toLongOrNull() ?: return
        val durationMs = parts.getOrNull(1)?.toLongOrNull() ?: -1L
        if (positionMs >= 0) {
            VShotsBrowserPlaybackService.updatePositionFromBrowser(
                positionMs = positionMs,
                durationMs = durationMs,
                generation = generation,
            )
        }
    }

    /** True once the CURRENT load's media has reached its natural end.
     *  Reset on every new load so each video reports end exactly once. */
    private var endedReported = false

    /** True once the CURRENT load's media entered its last 1.5 s — the
     *  app-wide auto-advance trigger (owner spec: next track starts just
     *  BEFORE the song fully ends). Reset on every new load. */
    private var nearEndReported = false

    /** True while the YouTube page is playing an in-stream ad. */
    private var adActive = false

    /** Explicit user pause guard. Polling must never fight the user. */
    private var userPaused = false

    /** Master switch for the ad assist (mute + official-skip click).
     *  Pushed from Dart (`enable_youtube_ad_assist` remote flag). */
    private var adAssistEnabled = true

    var mediaPlaying: Boolean = false
        private set

    private fun handlePollResult(state: String, generation: Long) {
        if (generation != loadGeneration) return
        val currentUrl = url ?: ""
        val lower = currentUrl.lowercase(Locale.US)
        val isYouTube = lower.contains("youtube.com") || lower.contains("youtu.be")

        when (state) {
            "ad" -> {
                setAdActive(true)
                // An ad is a page state, not a new playback command. Keep the
                // active-media bit for the notification action, but never call
                // play or request focus from this poll callback.
                setPlaybackState("ad", mediaPlaying)
                if (adAssistEnabled) runAdAssist()
            }
            else -> {
                if (adActive) setAdActive(false)
                when (state) {
                    "nearend" -> {
                        // Completion is emitted once, only while the real
                        // element is playing. The manager decides whether to
                        // advance; this layer never starts the next track.
                        if (isYouTube && !nearEndReported) {
                            nearEndReported = true
                            Log.d(TAG, "near-end completion reported")
                            events.invokeMethod("videoEnded", mapOf("generation" to loadGeneration))
                        }
                        setPlaybackState("playing", true)
                    }
                    "ended" -> {
                        if (isYouTube && !endedReported) {
                            endedReported = true
                            Log.d(TAG, "video.ended reported")
                            events.invokeMethod("videoEnded", mapOf("generation" to loadGeneration))
                        }
                        setPlaybackState("ended", false)
                    }
                    "playing" -> {
                        // A poll is read-only. It reports the element's
                        // observed state; it never turns a pause into play.
                        if (!userPaused) setPlaybackState("playing", true)
                        else setPlaybackState("paused", false)
                    }
                    "buffering" -> setPlaybackState("buffering", mediaPlaying)
                    "paused" -> setPlaybackState("paused", false)
                    else -> Unit // 'none' / 'unknown' — keep current state
                }
            }
        }
    }

    private fun setAdActive(value: Boolean) {
        if (adActive == value) return
        adActive = value
        Log.d(TAG, if (value) "in-stream ad started" else "in-stream ad ended")
        events.invokeMethod("adState", value)
    }

    /**
     * YouTube AD ASSIST (owner spec) — uses ONLY the controls the official
     * YouTube player itself exposes:
     *
     *   1. While an in-stream ad plays, the ad is muted (the app's music
     *      must not blast ad audio between songs).
     *   2. When YouTube shows its own "Skip" button, it is clicked — the
     *      same action a user performs. Unskippable ads are NEVER
     *      interfered with: they play (muted) in full.
     *   3. Nothing is blocked, hidden, resized or sped up. No ad-network
     *      interception, no unofficial APIs, no stream access.
     *
     * Gated by `enable_youtube_ad_assist` (remote flag, default ON).
     */
    private fun runAdAssist() {
        evaluateJavascript(YT_AD_ASSIST_JS) { result ->
            Log.d(TAG, "ad assist: ${cleanJsResult(result)}")
        }
    }

    init {
        VShotsBrowserPlaybackService.eventChannel = events
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.loadsImagesAutomatically = true
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false) // Block popup windows
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webChromeClient = object : WebChromeClient() {
            // Override to block popup windows completely
            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: android.os.Message?
            ): Boolean {
                // Block ALL popup windows
                popupBlockedCount++
                events.invokeMethod("blocked", "popup-window")
                return false
            }
        }

        webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                if (!isCurrentPage(url)) return
                events.invokeMethod("pageStarted", mapOf("generation" to loadGeneration))
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (!isCurrentPage(url)) return
                events.invokeMethod("pageFinished", mapOf("generation" to loadGeneration))
                startPlaybackPolling()
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                if (request?.isForMainFrame != false && isCurrentPage(request?.url?.toString())) {
                    events.invokeMethod(
                        "error",
                        mapOf(
                            "message" to "Playback failed — please retry",
                            "generation" to loadGeneration,
                        ),
                    )
                }
            }

            /**
             * NETWORK-LEVEL AD BLOCKING — Primary defense.
             * Intercepts ALL resource requests and blocks ads before they load.
             * Runs on BACKGROUND thread — never touch MethodChannel directly.
             *
             * IMPORTANT: YouTube ad blocking works by checking URL patterns
             * even on essential hosts (youtube.com, googlevideo.com, etc.)
             * because YouTube serves ads from the same domains as content.
             */
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? {
                return try {
                    val url = request?.url ?: return null
                    val urlStr = url.toString()

                    // Fast path: blocker disabled
                    if (!blockerEnabled) return null

                    val host = url.host?.lowercase(Locale.US) ?: return null
                    val path = url.path?.lowercase(Locale.US) ?: ""
                    val query = url.query?.lowercase(Locale.US) ?: ""

                    // YouTube (and Google ad CDNs used by the YouTube watch page)
                    // must never be intercepted — no ad-resource blocking.
                    if (isYouTubeDomain(host) || isYouTubeAdNetwork(host)) return null

                    // Essential hosts are NEVER blocked
                    if (matchesAnyHost(host, essentialHosts)) return null

                    // Host-based blocking
                    if (matchesAnyHost(host, blockedHosts)) {
                        reportBlock(host)
                        return emptyResponse()
                    }

                    // URL pattern blocking (catches ad paths, VAST/VPAID, etc.)
                    if (matchesAdPattern(urlStr, path, query)) {
                        reportBlock(host)
                        return emptyResponse()
                    }

                    // Allow everything else
                    null
                } catch (t: Throwable) {
                    // A blocker error must NEVER crash the WebView
                    null
                }
            }

            /**
             * Check if host is a YouTube domain.
             */
            private fun isYouTubeDomain(host: String): Boolean {
                val youtubeDomains = listOf(
                    "youtube.com",
                    "www.youtube.com",
                    "m.youtube.com",
                    "youtube-nocookie.com",
                    "youtu.be",
                    "ytimg.com",
                    "yt3.ggpht.com",
                    "yt3.googleusercontent.com",
                    "youtube-ui.l.google.com",
                    "youtubeembedded-pa.googleapis.com",
                    "youtube.googleapis.com",
                    "s.youtube.com",
                    "googlevideo.com",
                )
                return youtubeDomains.any { host == it || host.endsWith(".$it") }
            }

            /** Google ad CDNs used by the YouTube watch page — never blocked. */
            private fun isYouTubeAdNetwork(host: String): Boolean {
                val networks = listOf(
                    "doubleclick.net",
                    "googlesyndication.com",
                    "googleadservices.com",
                    "adservice.google.com",
                    "adservice.google.co.in",
                    "adservice.google.co.uk",
                )
                return networks.any { host == it || host.endsWith(".$it") }
            }

            /**
             * URL NAVIGATION BLOCKING — Blocks ad redirects/popups.
             * Intercepts navigation attempts before they happen.
             *
             * Includes YouTube-specific ad redirect blocking.
             */
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                val url = request?.url ?: return false
                val host = url.host?.lowercase(Locale.US) ?: return false
                val urlStr = url.toString()
                val path = url.path?.lowercase(Locale.US) ?: ""
                val query = url.query?.lowercase(Locale.US) ?: ""

                // Never intercept YouTube navigation or YouTube ad-network hosts.
                if (isYouTubeDomain(host) || isYouTubeAdNetwork(host)) return false

                // Allow essential hosts
                if (isAllowedHost(host)) return false

                // Block ad domains
                if (matchesAnyHost(host, blockedHosts)) {
                    reportBlock(host)
                    return true
                }

                // Block ad URL patterns in navigation
                if (matchesAdPattern(urlStr, path, query)) {
                    reportBlock(host)
                    return true
                }

                // Block suspicious redirects (non-HTTPS, data: URIs, javascript:)
                val scheme = url.scheme?.lowercase(Locale.US) ?: ""
                if (scheme != "https" && scheme != "http" && scheme != "javascript") {
                    if (scheme == "intent" || scheme == "market" || scheme == "tel" || scheme == "mailto") {
                        return false // Allow legitimate deep links
                    }
                    // Block suspicious schemes
                    reportBlock("suspicious-scheme:$scheme")
                    return true
                }

                return false
            }
        }
    }

    /**
     * Cosmetic ad blocking — hides residual ad containers via CSS.
     * Runs once per page load. Never touches video/audio/nav/content elements.
     * This is a SECONDARY defense after network-level blocking.
     *
     * Includes YOUTUBE-SPECIFIC ad selectors for YouTube pages.
     */
    /** Host == rule or endsWith ".rule" (e.g. "doubleclick.net" also matches
     *  "ad.doubleclick.net"). Conservative: no substring matching. */
    private fun matchesAnyHost(host: String, rules: Set<String>): Boolean {
        for (rule in rules) {
            if (host == rule || host.endsWith(".$rule")) return true
        }
        return false
    }

    /**
     * Check if URL matches known ad patterns (paths, queries, VAST/VPAID).
     * This catches ads served from legitimate domains via specific paths.
     */
    private fun matchesAdPattern(url: String, path: String, query: String): Boolean {
        val lowerUrl = url.lowercase(Locale.US)
        val lowerPath = path.lowercase(Locale.US)
        val lowerQuery = query.lowercase(Locale.US)

        for (pattern in adUrlPatterns) {
            val lowerPattern = pattern.lowercase(Locale.US)
            if (lowerPath.contains(lowerPattern) || lowerUrl.contains(lowerPattern)) {
                return true
            }
        }

        // VAST/VMAP/VPAID checks (only for non-YouTube hosts)
        if (lowerPath.contains("/vast") ||
            lowerPath.contains("/vmap") ||
            lowerPath.contains("/vpaid") ||
            lowerQuery.contains("vast") ||
            lowerQuery.contains("vmap") ||
            lowerQuery.contains("vpaid")) {
            // Don't block YouTube's internal VAST handling
            if (!lowerUrl.contains("youtube.com") && !lowerUrl.contains("youtu.be")) {
                return true
            }
        }

        return false
    }

    private fun isDeniedJioHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
        if (h == "api.jiosaavn.com" || h.endsWith(".api.jiosaavn.com")) return true
        if (h == "saavn.me" || h.endsWith(".saavn.me")) return true
        return false
    }

    private fun isAllowedHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
        if (isDeniedJioHost(h)) return false
        val allowed = listOf(
            "youtube.com",
            "youtu.be",
            "youtube-nocookie.com",
            "googlevideo.com",
            "ytimg.com",
            "google.com",
            "googleapis.com",
            "gstatic.com",
            "ggpht.com",
            "googleusercontent.com",
            "accounts.google.com",
            "play.google.com",
            "cloudflare.com",
            "supabase.co",
            "jiosaavn.com",
            "www.jiosaavn.com",
            "saavn.com",
            "www.saavn.com",
            "static.saavncdn.com",
            "c.saavncdn.com",
        )
        return allowed.any { h == it || h.endsWith(".$it") }
    }

    private fun reportBlock(host: String) {
        // Report to Dart on MAIN thread (stats only)
        val hostCopy = host
        handler.post { events.invokeMethod("blocked", hostCopy) }
    }

    private fun emptyResponse(): WebResourceResponse {
        return WebResourceResponse(
            "text/plain",
            "utf-8",
            ByteArrayInputStream(ByteArray(0)),
        )
    }

    private fun isCurrentPage(callbackUrl: String?): Boolean {
        if (callbackUrl.isNullOrEmpty() || currentLoadUrl.isEmpty()) return true
        if (callbackUrl == currentLoadUrl) return true
        val expected = Uri.parse(currentLoadUrl)
        val actual = Uri.parse(callbackUrl)
        val expectedVideo = expected.getQueryParameter("v")
        return if (!expectedVideo.isNullOrEmpty()) {
            callbackUrl.contains("v=$expectedVideo") ||
                callbackUrl.contains("/embed/$expectedVideo")
        } else {
            actual.host == expected.host
        }
    }

    fun load(url: String, requestedGeneration: Long? = null, autoplay: Boolean = true) {
        if (!url.startsWith("https://")) return
        val host = Uri.parse(url).host?.lowercase(Locale.US) ?: return
        if (isDeniedJioHost(host)) return
        loadGeneration = requestedGeneration ?: (loadGeneration + 1L)
        currentLoadUrl = url
        endedReported = false
        nearEndReported = false
        adActive = false
        userPaused = !autoplay
        mediaPlaying = false
        setPlaybackState("loading", false)
        playbackPoll.reset()
        // Cancel the previous document before starting a new generation. This
        // prevents late callbacks from the old navigation from becoming the
        // new track's page-finished/autoplay signal.
        stopLoading()
        loadUrl(url)
    }

    /** Toggles the YouTube ad assist (remote flag from Dart). */
    fun setAdAssist(enabled: Boolean) {
        adAssistEnabled = enabled
        Log.d(TAG, "ad assist ${if (enabled) "enabled" else "disabled"}")
    }

    /** Applies the compiled blocker configuration from Dart. Cheap sets only —
     *  no regex, no list reloads. Does NOT recreate the WebView. */
    fun setContentBlocker(
        enabled: Boolean,
        blocked: List<String>,
        essential: List<String>,
        patterns: List<String> = emptyList(),
    ) {
        blockerEnabled = enabled
        blockedHosts.clear()
        blockedHosts.addAll(blocked.map { it.lowercase(Locale.US) })
        essentialHosts.clear()
        essentialHosts.addAll(essential.map { it.lowercase(Locale.US) })
        adUrlPatterns.clear()
        adUrlPatterns.addAll(patterns)
    }

    private fun setPlaybackState(state: String, playing: Boolean) {
        val changed = playbackState != state || mediaPlaying != playing
        playbackState = state
        mediaPlaying = playing
        if (!changed) return
        startPlaybackForegroundService(playing = playing, state = state)
        events.invokeMethod(
            "playbackState",
            mapOf(
                "playing" to playing,
                "state" to state,
                "generation" to loadGeneration,
            ),
        )
    }

    fun updateNotification(title: String, artist: String, artwork: String, playing: Boolean) {
        notificationTitle = title
        notificationArtist = artist
        notificationArtwork = artwork
        // Metadata updates use the authoritative native state. The Dart flag
        // is intentionally not allowed to request play or audio focus.
        startPlaybackForegroundService(
            title = notificationTitle,
            artist = notificationArtist,
            artwork = notificationArtwork,
            playing = mediaPlaying,
            state = playbackState,
        )
    }

    private fun startPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
        handler.post(playbackPoll)
    }

    private fun stopPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
    }

    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        artwork: String? = null,
        playing: Boolean = mediaPlaying,
        positionMs: Long = -1L,
        durationMs: Long = -1L,
        state: String = playbackState,
        userCommand: String? = null,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: notificationTitle)
            putExtra("artist", artist ?: notificationArtist)
            putExtra("artwork", artwork ?: notificationArtwork)
            putExtra("playing", playing)
            putExtra("state", state)
            putExtra("generation", loadGeneration)
            if (userCommand != null) putExtra("userCommand", userCommand)
            putExtra("positionMs", positionMs)
            putExtra("durationMs", durationMs)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: Exception) {
            // FGS startup is a hardening layer and must never crash Discovery.
        }
    }

    private fun stopPlaybackForegroundService() {
        try {
            appContext.stopService(
                Intent(appContext, VShotsBrowserPlaybackService::class.java),
            )
        } catch (_: Exception) {
            // Best effort only.
        }
    }

    fun pauseMedia(userInitiated: Boolean = true) {
        if (userInitiated) userPaused = true
        evaluateJavascript(
            """
            (function(){
              var v=document.querySelector('video,audio');
              if(!v){return 'none';}
              if(!v.paused){ v.pause(); }
              return 'paused';
            })()
            """.trimIndent(),
        ) { _ ->
            setPlaybackState("paused", false)
        }
        setPlaybackState("paused", false)
        if (userInitiated) {
            startPlaybackForegroundService(
                playing = false,
                state = "paused",
                userCommand = "pause",
            )
        }
    }

    fun userPlay() {
        userPaused = false
        startPlaybackForegroundService(
            playing = mediaPlaying,
            state = playbackState,
            userCommand = "play",
        )
        evaluateJavascript(
            """
            (function(){
              var v=document.querySelector('video,audio');
              if(!v){return 'none';}
              v.muted=false; v.volume=1;
              var p=v.play();
              if(p && p.catch){p.catch(function(){});}
              return 'requested';
            })()
            """.trimIndent(),
        ) { _ ->
            // The following poll/state callback is authoritative. This
            // command does not optimistically grant focus or mark PLAYING.
        }
    }

    private fun cleanJsResult(result: String?): String {
        return result.orEmpty().trim().trim('"').lowercase(Locale.US)
    }

    /** Keep active WebView media alive across Android visibility changes. */
    override fun onWindowVisibilityChanged(visibility: Int) {
        if (mediaPlaying) {
            super.onWindowVisibilityChanged(View.VISIBLE)
        } else {
            super.onWindowVisibilityChanged(visibility)
        }
    }

    /** Do not pause active Discovery media just because the Activity is hidden. */
    override fun onPause() {
        if (mediaPlaying) return
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        // Explicit user pause is authoritative; resume only via Play.
    }

    fun disposeMedia() {
        loadGeneration++
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        playbackState = "idle"
        mediaPlaying = false
        stopLoading()
        loadUrl("about:blank")
    }
}

private class VShotsBrowserPlatformView(
    context: Context,
    id: Int,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformView {
    private val channel = MethodChannel(messenger, "vshots/browser/$id")
    private val webView = VShotsBackgroundMediaWebView(context, channel)

    init {
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "load" -> {
                    val args = call.arguments as? Map<*, *>
                    val url = args?.get("url")?.toString()
                        ?: (call.arguments as? String)
                        ?: ""
                    val generation = (args?.get("generation") as? Number)?.toLong()
                    val autoplay = args?.get("autoplay") as? Boolean ?: true
                    webView.load(url, generation, autoplay)
                    result.success(null)
                }
                "pause" -> {
                    webView.pauseMedia(userInitiated = true)
                    result.success(null)
                }
                "focusPause" -> {
                    webView.pauseMedia(userInitiated = false)
                    result.success(null)
                }
                "play" -> {
                    webView.userPlay()
                    result.success(null)
                }
                "setContentBlocker" -> {
                    try {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        val enabled = (args["enabled"] as? Boolean) ?: true
                        val blocked = (args["blocked"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        val essential = (args["essential"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        val patterns = (args["patterns"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        webView.setContentBlocker(enabled, blocked, essential, patterns)
                        result.success(null)
                    } catch (t: Throwable) {
                        // A blocker-config error must never take the browser down.
                        result.success(null)
                    }
                }
                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
                "updateNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title")?.toString() ?: "V Shots"
                    val artist = args?.get("artist")?.toString() ?: "Music playback"
                    val artwork = args?.get("artwork")?.toString() ?: ""
                    val playing = args?.get("playing") as? Boolean ?: false
                    webView.updateNotification(title, artist, artwork, playing)
                    result.success(null)
                }
                "seekBy" -> {
                    // Seek the REAL media element (±seconds) without
                    // recreating the WebView. Used by the notification's
                    // rewind / fast-forward buttons and the media session.
                    val seconds = (call.arguments as? Number)?.toInt() ?: 10
                    webView.evaluateJavascript(
                        """(function(){
                          try{
                            var v=document.querySelector('video,audio');
                            if(!v){return 'none';}
                            var d=(v.duration&&isFinite(v.duration))?v.duration:null;
                            var t=v.currentTime+($seconds);
                            if(d!=null){t=Math.max(0,Math.min(d,t));}
                            else{t=Math.max(0,t);}
                            v.currentTime=t;
                            return 'ok';
                          }catch(e){return 'err';}
                        })()""",
                    ) { _ -> }
                    result.success(null)
                }
                "setVolume" -> {
                    // Audio-focus ducking: 0..1 on the real media element.
                    // Volume 0 also unmutes so ducked playback is audible.
                    val raw = (call.arguments as? Number)?.toDouble() ?: 1.0
                    val volume = Math.max(0.0, Math.min(1.0, raw))
                    webView.evaluateJavascript(
                        """(function(){
                          try{
                            var v=document.querySelector('video,audio');
                            if(!v){return 'none';}
                            v.muted=false;
                            v.volume=$volume;
                            return 'ok';
                          }catch(e){return 'err';}
                        })()""",
                    ) { _ -> }
                    result.success(null)
                }
                "dispose" -> {
                    webView.disposeMedia()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }


    override fun getView(): View = webView

    override fun dispose() {
        webView.disposeMedia()
        channel.setMethodCallHandler(null)
        webView.destroy()
    }
}

class VShotsBrowserPlatformViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return VShotsBrowserPlatformView(context, viewId, messenger)
    }
}
